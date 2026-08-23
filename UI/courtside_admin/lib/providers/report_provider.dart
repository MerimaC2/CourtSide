import 'dart:io';
import 'dart:typed_data';

import 'package:http/io_client.dart';

import '../config/app_config.dart';
import '../utils/authorization.dart';
import '../utils/util.dart';

/// Downloads the admin PDF report. Not a [BaseProvider] subclass — the response
/// body is binary (application/pdf), not JSON.
class ReportProvider {
  late final IOClient _http;

  ReportProvider() {
    final client = HttpClient()..badCertificateCallback = (cert, host, port) => true;
    _http = IOClient(client);
  }

  /// [language] is the UI language the report should be written in; the PDF is
  /// rendered on the server, so it can't pick this up on its own.
  Future<Uint8List> getReservationsReport({
    DateTime? dateFrom,
    DateTime? dateTo,
    int? sportCenterId,
    String language = 'bs',
  }) async {
    final params = <String, String>{
      if (dateFrom != null) 'dateFrom': formatApiDate(dateFrom),
      if (dateTo != null) 'dateTo': formatApiDate(dateTo),
      if (sportCenterId != null) 'sportCenterId': sportCenterId.toString(),
      'language': language,
    };
    final uri = Uri.parse('${AppConfig.apiBase}reports/reservations')
        .replace(queryParameters: params.isEmpty ? null : params);
    final headers = <String, String>{};
    if (Authorization.token != null && Authorization.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${Authorization.token}';
    }
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode >= 300) {
      throw Exception('Greška pri generisanju izvještaja (HTTP ${response.statusCode}).');
    }
    return response.bodyBytes;
  }
}
