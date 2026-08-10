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
      );

  bool get isActive => status == 'Pending' || status == 'Confirmed';

  String get timeRange => '${startTime.substring(0, 5)} - ${endTime.substring(0, 5)}';
}
