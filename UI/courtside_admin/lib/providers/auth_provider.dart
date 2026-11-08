import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';

import '../models/auth_user.dart';
import '../utils/authorization.dart';
import 'base_provider.dart';

/// Authentication against POST /api/auth/login. Stores the JWT + claims in [Authorization].
/// Admin accounts are pre-seeded server-side — this app has no registration flow.
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

    if (response.statusCode >= 300) {
      String message = 'Pogrešno korisničko ime ili lozinka.';
      try {
        final body = jsonDecode(response.body);
        message = (body['message'] as String?)?.trim() ?? message;
      } catch (_) {}
      throw Exception(message);
    }

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
  /// Returns whether the server confirmed the sign-out (trivially so when there was no
  /// token), so the caller can tell the user when the token may still be valid there.
  Future<bool> signOut() async {
    final token = Authorization.token;
    var confirmed = true;
    if (token != null && token.isNotEmpty) {
      try {
        final response = await _http
            .post(
              Uri.parse('${_baseUrl}auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(_logoutTimeout);
        // The client does not throw on an HTTP error, so a refusal has to be checked here.
        // 401 means the server already rejects this token (expired or revoked), which is
        // exactly what signing out is meant to achieve.
        if (response.statusCode >= 300 && response.statusCode != 401) {
          debugPrint('Odjava na serveru odbijena: HTTP ${response.statusCode}');
          confirmed = false;
        }
      } catch (e) {
        // Offline, unreachable or too slow — the local sign-out below still applies,
        // but the token stays valid on the server until it expires.
        debugPrint('Odjava na serveru nije uspjela: $e');
        confirmed = false;
      }
    }
    Authorization.clear();
    notifyListeners();
    return confirmed;
  }
}
