import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

import '../config/app_config.dart';
import 'api_error.dart';
import '../models/search_result.dart';
import '../utils/app_navigator.dart';
import '../utils/authorization.dart';

/// Generic CRUD provider over the REST API (mirrors the course BaseProvider pattern).
/// Subclasses set the [endpoint] (e.g. 'courts') and override [fromJson]/[toJson].
abstract class BaseProvider<T> with ChangeNotifier {
  static String get baseUrl => AppConfig.apiBase;

  /// The largest page the API will serve; it clamps anything bigger, so asking for more
  /// silently drops records. Used where a whole set is needed at once, such as the values
  /// behind a form's dropdown.
  static const int maxPageSize = 100;

  final String endpoint;
  late final IOClient http;

  BaseProvider(this.endpoint) {
    final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
    http = IOClient(client);
  }

  /// GET list. Handles PagedResult ({items,totalCount}) and raw arrays.
  Future<SearchResult<T>> get({Map<String, dynamic>? filter}) async {
    var url = '$baseUrl$endpoint';
    if (filter != null && filter.isNotEmpty) {
      url = '$url?${getQueryString(filter)}';
    }
    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final result = SearchResult<T>();
      final List items = data is List
          ? data
          : (data['items'] as List? ?? data['result'] as List? ?? const []);
      result.count =
          data is Map ? (data['totalCount'] as int? ?? items.length) : items.length;
      for (final item in items) {
        result.result.add(fromJson(item as Map<String, dynamic>));
      }
      return result;
    }
    throw Exception('Greška pri dohvatu podataka.');
  }

  Future<T> getById(int id) async {
    final response =
        await http.get(Uri.parse('$baseUrl$endpoint/$id'), headers: createHeaders());
    if (isValidResponse(response)) {
      return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Nije pronađeno.');
  }

  Future<T> addAsync(Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$baseUrl$endpoint'),
        headers: createHeaders(), body: jsonEncode(body));
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<T> updateAsync(int id, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$baseUrl$endpoint/$id'),
        headers: createHeaders(), body: jsonEncode(body));
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteById(int id) async {
    final response =
        await http.delete(Uri.parse('$baseUrl$endpoint/$id'), headers: createHeaders());
    isValidResponse(response);
  }

  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T item) => throw UnimplementedError();

  bool isValidResponse(Response response) {
    if (response.statusCode < 300) return true;
    if (response.statusCode == 401) {
      Authorization.clear();
      onUnauthorized?.call();
      throw Exception('Sesija je istekla. Prijavite se ponovo.');
    }
    if (response.statusCode == 403) {
      // A role check answers with an empty body, but a service that refuses because the record
      // belongs to someone else says why — that reason is more useful than a generic sentence.
      final message = errorMessageFrom(response);
      throw Exception(
          message.startsWith('HTTP ') ? 'Nemate ovlaštenje za ovu radnju.' : message);
    }
    throw Exception(errorMessageFrom(response));
  }

  Map<String, String> createHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (Authorization.token != null && Authorization.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${Authorization.token}';
    }
    return headers;
  }

  String getQueryString(Map<String, dynamic> params, {String prefix = ''}) {
    final parts = <String>[];
    params.forEach((key, value) {
      if (value == null) return;
      if (value is DateTime) {
        parts.add('$key=${Uri.encodeComponent(value.toIso8601String())}');
      } else {
        parts.add('$key=${Uri.encodeComponent(value.toString())}');
      }
    });
    return parts.join('&');
  }
}
