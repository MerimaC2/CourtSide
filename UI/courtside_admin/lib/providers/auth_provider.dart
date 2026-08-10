import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';

import '../models/auth_user.dart';
import '../utils/authorization.dart';
import 'base_provider.dart';

/// Authentication against POST /api/auth/login. Stores the JWT + claims in [Authorization].
/// Admin accounts are pre-seeded server-side — this app has no registration flow.
class AuthProvider with ChangeNotifier {
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

  void signOut() => Authorization.clear();
}
