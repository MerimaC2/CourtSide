class AvailabilitySlot {
  final String startTime;
  final String endTime;
  final String status;

  AvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) => AvailabilitySlot(
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        status: json['status'] as String? ?? 'Available',
      );

  bool get isAvailable => status == 'Available';

  String get label => '${startTime.substring(0, 5)} - ${endTime.substring(0, 5)}';
}
