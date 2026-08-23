class CourtReview {
  final int id;
  final int courtId;
  final String? userName;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  CourtReview({
    required this.id,
    required this.courtId,
    this.userName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory CourtReview.fromJson(Map<String, dynamic> json) => CourtReview(
        id: json['id'] as int,
        courtId: json['courtId'] as int? ?? 0,
        userName: json['userName'] as String?,
        rating: json['rating'] as int? ?? 0,
        comment: json['comment'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
