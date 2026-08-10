class AvailabilityBlock {
  final int id;
  final int courtId;
  final String? courtName;
  final String date;
  final String startTime;
  final String endTime;
  final String? reason;

  AvailabilityBlock({
    required this.id,
    required this.courtId,
    this.courtName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  factory AvailabilityBlock.fromJson(Map<String, dynamic> json) => AvailabilityBlock(
        id: json['id'] as int,
        courtId: json['courtId'] as int? ?? 0,
        courtName: json['courtName'] as String?,
        date: (json['date'] as String? ?? '').split('T').first,
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        reason: json['reason'] as String?,
      );
}
