import 'package:http/http.dart';

import '../models/news.dart';
import '../utils/authorization.dart';
import 'base_provider.dart';

class NewsProvider extends BaseProvider<News> {
  NewsProvider() : super('news');

  @override
  News fromJson(Map<String, dynamic> json) => News.fromJson(json);

  Future<void> uploadImage(int newsId, List<int> bytes, String filename, String contentType) async {
    final uri = Uri.parse('${BaseProvider.baseUrl}news/$newsId/image');
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
      throw Exception(response.body.isNotEmpty ? response.body : 'HTTP ${response.statusCode}');
    }
  }
}
