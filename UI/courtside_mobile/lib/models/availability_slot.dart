class AvailabilitySlot {
  final String startTime;
  final String endTime;
  final String status;

  /// Decided by the server against the venue's local time — the device clock and time zone
  /// would not necessarily agree with the rules the API enforces.
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

  /// Free and still ahead of us — the only combination the server will accept.
  bool get isBookable => status == 'Available' && !isPast;

  bool get isAvailable => status == 'Available';

  String get label => '${startTime.substring(0, 5)} - ${endTime.substring(0, 5)}';
}
