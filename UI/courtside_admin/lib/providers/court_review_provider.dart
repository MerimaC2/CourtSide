import '../models/court_review.dart';
import 'base_provider.dart';

class CourtReviewProvider extends BaseProvider<CourtReview> {
  CourtReviewProvider() : super('courtreviews');

  @override
  CourtReview fromJson(Map<String, dynamic> json) => CourtReview.fromJson(json);
}
