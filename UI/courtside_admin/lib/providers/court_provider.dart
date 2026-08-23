import 'package:http/http.dart';

import '../models/court.dart';
import '../utils/authorization.dart';
import 'base_provider.dart';

class CourtProvider extends BaseProvider<Court> {
  CourtProvider() : super('courts');

  @override
  Court fromJson(Map<String, dynamic> json) => Court.fromJson(json);

  Future<void> uploadImage(int courtId, List<int> bytes, String filename, String contentType) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}courts/$courtId/images');
    final request = MultipartRequest('POST', uri);
    if (Authorization.token != null) {
      request.headers['Authorization'] = 'Bearer ${Authorization.token}';
    }
    final parts = contentType.split('/');
    request.files.add(MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType(parts.first, parts.length > 1 ? parts[1] : 'jpeg'),
    ));
    final streamed = await http.send(request);
    final response = await Response.fromStream(streamed);
    if (response.statusCode >= 300) {
      String message = 'HTTP ${response.statusCode}';
      try {
        if (response.body.isNotEmpty) message = response.body;
      } catch (_) {}
      throw Exception(message);
    }
  }
}
