class Court {
  final int id;
  final String name;
  final String? description;
  final int sportId;
  final String? sportName;
  final int sportCenterId;
  final String? sportCenterName;
  final double pricePerHour;
  final bool isActive;
  final int? primaryImageId;
  final double? averageRating;
  final int reviewCount;

  Court({
    required this.id,
    required this.name,
    this.description,
    required this.sportId,
    this.sportName,
    required this.sportCenterId,
    this.sportCenterName,
    required this.pricePerHour,
    required this.isActive,
    this.primaryImageId,
    this.averageRating,
    this.reviewCount = 0,
  });

  factory Court.fromJson(Map<String, dynamic> json) => Court(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        sportId: json['sportId'] as int? ?? 0,
        sportName: json['sportName'] as String?,
        sportCenterId: json['sportCenterId'] as int? ?? 0,
        sportCenterName: json['sportCenterName'] as String?,
        pricePerHour: (json['pricePerHour'] as num?)?.toDouble() ?? 0,
        isActive: json['isActive'] as bool? ?? false,
        primaryImageId: json['primaryImageId'] as int?,
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        reviewCount: json['reviewCount'] as int? ?? 0,
      );
}
