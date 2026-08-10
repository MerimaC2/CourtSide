class Recommendation {
  final int courtId;
  final String courtName;
  final String? sportName;
  final String? sportCenterName;
  final double pricePerHour;
  final int? primaryImageId;
  final double score;
  final String reason;

  Recommendation({
    required this.courtId,
    required this.courtName,
    this.sportName,
    this.sportCenterName,
    required this.pricePerHour,
    this.primaryImageId,
    required this.score,
    required this.reason,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
        courtId: json['courtId'] as int? ?? 0,
        courtName: json['courtName'] as String? ?? '',
        sportName: json['sportName'] as String?,
        sportCenterName: json['sportCenterName'] as String?,
        pricePerHour: (json['pricePerHour'] as num?)?.toDouble() ?? 0,
        primaryImageId: json['primaryImageId'] as int?,
        score: (json['score'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String? ?? '',
      );
}
