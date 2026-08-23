class CourtReview {
  final int id;
  final int courtId;
  final String? courtName;
  final int userId;
  final String? userName;
  final int? reservationId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  CourtReview({
    required this.id,
    required this.courtId,
    this.courtName,
    required this.userId,
    this.userName,
    this.reservationId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory CourtReview.fromJson(Map<String, dynamic> json) => CourtReview(
        id: json['id'] as int,
        courtId: json['courtId'] as int? ?? 0,
        courtName: json['courtName'] as String?,
        userId: json['userId'] as int? ?? 0,
        userName: json['userName'] as String?,
        reservationId: json['reservationId'] as int?,
        rating: json['rating'] as int? ?? 0,
        comment: json['comment'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
