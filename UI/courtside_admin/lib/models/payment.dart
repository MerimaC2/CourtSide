class Payment {
  final int reservationId;
  final String method;
  final double amount;
  final String currency;
  final String status;
  final String? stripePaymentIntentId;
  final DateTime? paidAt;
  final double? refundedAmount;
  final DateTime? refundedAt;

  Payment({
    required this.reservationId,
    required this.method,
    required this.amount,
    required this.currency,
    required this.status,
    this.stripePaymentIntentId,
    this.paidAt,
    this.refundedAmount,
    this.refundedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        reservationId: json['reservationId'] as int? ?? 0,
        method: json['method'] as String? ?? 'Cash',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'BAM',
        status: json['status'] as String? ?? 'Pending',
        stripePaymentIntentId: json['stripePaymentIntentId'] as String?,
        paidAt: DateTime.tryParse(json['paidAt'] as String? ?? ''),
        refundedAmount: (json['refundedAmount'] as num?)?.toDouble(),
        refundedAt: DateTime.tryParse(json['refundedAt'] as String? ?? ''),
      );
}
