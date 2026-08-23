import 'court_working_hours.dart';

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
  final List<CourtWorkingHours> workingHours;

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
    this.workingHours = const [],
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
        workingHours: ((json['workingHours'] as List?) ?? const [])
            .map((e) => CourtWorkingHours.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
