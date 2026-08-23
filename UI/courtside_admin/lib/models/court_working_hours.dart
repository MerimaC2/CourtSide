/// Opening hours of a court on one day of the week. Availability is generated from
/// these, so a court without any has no bookable slots.
///
/// [dayOfWeek] is the .NET `DayOfWeek` name as the API serialises it ("Monday" … "Sunday").
class CourtWorkingHours {
  final String dayOfWeek;
  final String openTime;
  final String closeTime;

  CourtWorkingHours({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
  });

  factory CourtWorkingHours.fromJson(Map<String, dynamic> json) => CourtWorkingHours(
        dayOfWeek: json['dayOfWeek']?.toString() ?? '',
        openTime: json['openTime'] as String? ?? '08:00:00',
        closeTime: json['closeTime'] as String? ?? '22:00:00',
      );

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'openTime': openTime,
        'closeTime': closeTime,
      };
}
