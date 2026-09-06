class AvailabilitySlot {
  final String startTime;
  final String endTime;
  final String status;

  /// Decided by the server against the venue's local time; a slot that has started can no
  /// longer be blocked, so the schedule shows it as spent rather than as free.
  final bool isPast;

  AvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.isPast,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) => AvailabilitySlot(
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        status: json['status'] as String? ?? 'Available',
        isPast: json['isPast'] as bool? ?? false,
      );

  String get label => '${startTime.substring(0, 5)} - ${endTime.substring(0, 5)}';
}
