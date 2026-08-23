import '../models/court_review.dart';
import 'base_provider.dart';

class CourtReviewProvider extends BaseProvider<CourtReview> {
  CourtReviewProvider() : super('courtreviews');

  @override
  CourtReview fromJson(Map<String, dynamic> json) => CourtReview.fromJson(json);

  Future<CourtReview> submit({required int reservationId, required int rating, String? comment}) {
    return addAsync({
      'reservationId': reservationId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }
}
