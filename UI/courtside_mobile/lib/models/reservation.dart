class Reservation {
  final int id;
  final String reservationNumber;
  final int clientId;
  final String? clientName;
  final int courtId;
  final String? courtName;
  final String? sportCenterName;
  final String date;
  final String startTime;
  final String endTime;
  final double totalPrice;
  final String status;
  final String contactName;
  final String contactPhone;
  final String? note;
  final String? cancellationReason;
  final DateTime? createdAt;
  final String? paymentMethod;
  final String? paymentStatus;
  final bool isPaid;
  final bool hasReview;

  /// Decided by the server, which owns the venue's time zone and the cancellation rule.
  /// Computing it from device time would disagree with what the API actually enforces.
  final bool canCancel;

  /// Set by the server when this card-paid reservation is still active and unpaid, so a
  /// payment can be started (again) from the reservations list.
  final bool canPayOnline;
  final DateTime? startsAt;

  /// As the venue's clock reads it: the date and time the server wrote, without converting
  /// to the device's zone, so it lines up with [startTime] wherever the device is.
  final DateTime? cancelDeadlineAt;

  Reservation({
    required this.id,
    required this.reservationNumber,
    required this.clientId,
    this.clientName,
    required this.courtId,
    this.courtName,
    this.sportCenterName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    required this.contactName,
    required this.contactPhone,
    this.note,
    this.cancellationReason,
    this.createdAt,
    this.paymentMethod,
    this.paymentStatus,
    required this.isPaid,
    required this.hasReview,
    required this.canCancel,
    this.canPayOnline = false,
    this.startsAt,
    this.cancelDeadlineAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as int,
        reservationNumber: json['reservationNumber'] as String? ?? '',
        clientId: json['clientId'] as int? ?? 0,
        clientName: json['clientName'] as String?,
        courtId: json['courtId'] as int? ?? 0,
        courtName: json['courtName'] as String?,
        sportCenterName: json['sportCenterName'] as String?,
        date: (json['date'] as String? ?? '').split('T').first,
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'Pending',
        contactName: json['contactName'] as String? ?? '',
        contactPhone: json['contactPhone'] as String? ?? '',
        note: json['note'] as String?,
        cancellationReason: json['cancellationReason'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        paymentMethod: json['paymentMethod'] as String?,
        paymentStatus: json['paymentStatus'] as String?,
        isPaid: json['isPaid'] as bool? ?? false,
        hasReview: json['hasReview'] as bool? ?? false,
        canCancel: json['canCancel'] as bool? ?? false,
        canPayOnline: json['canPayOnline'] as bool? ?? false,
        startsAt: DateTime.tryParse(json['startsAt'] as String? ?? '')?.toLocal(),
        cancelDeadlineAt: _wallClock(json['cancelDeadlineAt'] as String?),
      );

  bool get isActive => status == 'Pending' || status == 'Confirmed';

  String get timeRange => '${startTime.substring(0, 5)} - ${endTime.substring(0, 5)}';

  /// Orders by when the slot starts: date, then start time. Both are zero-padded
  /// (`yyyy-MM-dd`, `HH:mm:ss`), so comparing the text gives chronological order.
  int compareStart(Reservation other) {
    final byDate = date.compareTo(other.date);
    return byDate != 0 ? byDate : startTime.compareTo(other.startTime);
  }
}

/// Date and time part of an ISO timestamp; the UTC offset after it is left out.
final _wallClockPattern = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?');

DateTime? _wallClock(String? value) {
  final match = _wallClockPattern.firstMatch(value ?? '');
  return match == null ? null : DateTime.tryParse(match.group(0)!);
}
