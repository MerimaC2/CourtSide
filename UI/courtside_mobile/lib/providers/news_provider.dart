import '../models/news.dart';
import 'base_provider.dart';

class NewsProvider extends BaseProvider<News> {
  NewsProvider() : super('news');

  @override
  News fromJson(Map<String, dynamic> json) => News.fromJson(json);
}
