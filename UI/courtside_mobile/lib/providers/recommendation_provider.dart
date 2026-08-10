import '../models/recommendation.dart';
import 'base_provider.dart';

class RecommendationProvider extends BaseProvider<Recommendation> {
  RecommendationProvider() : super('recommendations');

  @override
  Recommendation fromJson(Map<String, dynamic> json) => Recommendation.fromJson(json);

  Future<List<Recommendation>> getRecommendations({int count = 3}) async {
    final result = await get(filter: {'count': count});
    return result.result;
  }
}
