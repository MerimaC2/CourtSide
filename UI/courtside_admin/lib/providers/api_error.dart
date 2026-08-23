import 'dart:convert';

import 'package:http/http.dart';

/// Turns a failed API response into the most specific message available.
///
/// The API reports problems in two shapes: a business rule failure carries a single
/// `message`, while model validation returns an `errors` map keyed by field. The
/// field messages are the useful ones, so they're preferred over the generic
/// "One or more validation errors occurred." title that accompanies them.
String errorMessageFrom(Response response) {
  try {
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      final message = (body['message'] as String?)?.trim();
      if (message != null && message.isNotEmpty) return message;

      final errors = body['errors'];
      if (errors is Map<String, dynamic>) {
        final messages = errors.values
            .whereType<List<dynamic>>()
            .expand((list) => list.map((e) => e.toString().trim()))
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (messages.isNotEmpty) return messages.join('\n');
      }

      final title = (body['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) return title;
    }
  } catch (_) {
    // Not JSON — fall through to the raw body below.
  }
  return response.body.isNotEmpty ? response.body : 'HTTP ${response.statusCode}';
}
