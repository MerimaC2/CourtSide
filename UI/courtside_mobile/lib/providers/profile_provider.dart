import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/profile.dart';
import '../utils/authorization.dart';
import 'api_error.dart';

/// The current user's own profile: GET/PUT /api/profile, change-password and image upload.
/// Kept separate from [BaseProvider] since it targets a single, non-list resource with a
/// multipart image endpoint rather than the generic paged-CRUD shape.
class ProfileProvider with ChangeNotifier {
  static String get _baseUrl => AppConfig.apiBase;
  late final IOClient _http;

  ProfileProvider() {
    final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
    _http = IOClient(client);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (Authorization.token != null) 'Authorization': 'Bearer ${Authorization.token}',
      };

  Future<Profile> get() async {
    final response = await _http.get(Uri.parse('${_baseUrl}profile'), headers: _headers);
    _checkOk(response);
    return Profile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Profile> update({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    final response = await _http.put(
      Uri.parse('${_baseUrl}profile'),
      headers: _headers,
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      }),
    );
    _checkOk(response);
    return Profile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final response = await _http.post(
      Uri.parse('${_baseUrl}profile/change-password'),
      headers: _headers,
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    _checkOk(response);
  }

  Future<void> uploadImage(List<int> bytes, String filename, String contentType) async {
    final uri = Uri.parse('${_baseUrl}profile/image');
    final request = http.MultipartRequest('POST', uri);
    if (Authorization.token != null) {
      request.headers['Authorization'] = 'Bearer ${Authorization.token}';
    }
    final parts = contentType.split('/');
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType(parts.first, parts.length > 1 ? parts[1] : 'jpeg'),
    ));
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    _checkOk(response);
  }

  /// URL for `Image.network` — needs the Authorization header passed separately since the
  /// endpoint is behind JWT auth.
  String get imageUrl => '${_baseUrl}profile/image';

  void _checkOk(http.Response response) {
    if (response.statusCode < 300) return;
    throw Exception(errorMessageFrom(response));
  }
}
