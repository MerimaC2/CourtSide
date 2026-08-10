import '../models/court.dart';
import 'base_provider.dart';

class CourtProvider extends BaseProvider<Court> {
  CourtProvider() : super('courts');

  @override
  Court fromJson(Map<String, dynamic> json) => Court.fromJson(json);

  /// Logs an implicit "viewed this court" signal for the recommender.
  Future<void> logView(int id) async {
    final response = await http.post(
        Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/view'),
        headers: createHeaders());
    isValidResponse(response);
  }
}
