import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

import '../models/auth_user.dart';
import 'api_error.dart';
import '../utils/authorization.dart';
import 'base_provider.dart';

/// Authentication against POST /api/auth/login and /api/auth/register.
/// Stores the JWT + claims in [Authorization].
class AuthProvider with ChangeNotifier {
  /// Telling the server about the sign-out is best effort, so the request is capped: an
  /// unreachable API must not leave the user stuck on a screen they asked to leave.
  static const _logoutTimeout = Duration(seconds: 3);

  static String get _baseUrl => BaseProvider.baseUrl;
  late final IOClient _http;

  AuthProvider() {
    final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
    _http = IOClient(client);
  }

  Future<AuthUser> signIn(String username, String password) async {
    final response = await _http.post(
      Uri.parse('${_baseUrl}auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _handleAuthResponse(response, fallbackError: 'Pogrešno korisničko ime ili lozinka.');
  }

  Future<AuthUser> signUp({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    final response = await _http.post(
      Uri.parse('${_baseUrl}auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      }),
    );
    return _handleAuthResponse(response, fallbackError: 'Registracija nije uspjela.');
  }

  /// Asks the server to email a one-time code. The answer is the same whether or not the
  /// address is registered, so the screen can only report that the email was sent.
  Future<void> requestPasswordReset(String email) async {
    final response = await _http.post(
      Uri.parse('${_baseUrl}auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    _ensureSuccess(response, fallbackError: 'Slanje koda nije uspjelo.');
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _http.post(
      Uri.parse('${_baseUrl}auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'newPassword': newPassword}),
    );
    _ensureSuccess(response, fallbackError: 'Postavljanje nove lozinke nije uspjelo.');
  }

  void _ensureSuccess(Response response, {required String fallbackError}) {
    if (response.statusCode < 300) return;
    final message = errorMessageFrom(response);
    // An empty body leaves only the status code, which means nothing to the user.
    throw Exception(message.startsWith('HTTP ') ? fallbackError : message);
  }

  AuthUser _handleAuthResponse(Response response, {required String fallbackError}) {
    _ensureSuccess(response, fallbackError: fallbackError);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);

    Authorization.token = data['token'] as String?;
    Authorization.userId = user.id;
    Authorization.username = user.username;
    Authorization.firstName = user.firstName;
    Authorization.lastName = user.lastName;
    Authorization.role = user.role;

    return user;
  }


  /// Tells the API to invalidate this token, then clears it locally. A failure here
  /// must not trap the user in the app, so the local session is cleared either way.
  ///
  /// Returns false when there was a session but the server did not confirm ending it, so
  /// the caller can tell the user the token may stay valid on the server until it expires.
  Future<bool> signOut() async {
    var confirmed = true;
    final token = Authorization.token;
    if (token != null && token.isNotEmpty) {
      try {
        final response = await _http
            .post(
              Uri.parse('${_baseUrl}auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(_logoutTimeout);
        // The client does not throw on an HTTP error, so a refusal is checked explicitly.
        // 401 means the server already rejects this token (expired or revoked), which is
        // exactly what signing out is meant to achieve.
        if (response.statusCode >= 300 && response.statusCode != 401) {
          confirmed = false;
          debugPrint('Odjava na serveru odbijena: HTTP ${response.statusCode}');
        }
      } catch (e) {
        // Offline, unreachable or too slow — the local sign-out below still applies,
        // but the token stays valid on the server until it expires.
        confirmed = false;
        debugPrint('Odjava na serveru nije uspjela: $e');
      }
    }
    Authorization.clear();
    notifyListeners();
    return confirmed;
  }
}
