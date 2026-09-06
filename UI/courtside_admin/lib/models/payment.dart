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
  final String? refundFailureReason;
  final DateTime? refundRequestedAt;

  /// Which actions the payment rules allow right now — decided by the server so the buttons
  /// can never offer something the API would refuse.
  final bool canCollectCash;
  final bool canRefund;
  final bool canConfirmCashRefund;

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
    this.refundFailureReason,
    this.refundRequestedAt,
    this.canCollectCash = false,
    this.canRefund = false,
    this.canConfirmCashRefund = false,
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
        refundFailureReason: json['refundFailureReason'] as String?,
        refundRequestedAt: DateTime.tryParse(json['refundRequestedAt'] as String? ?? ''),
        canCollectCash: json['canCollectCash'] as bool? ?? false,
        canRefund: json['canRefund'] as bool? ?? false,
        canConfirmCashRefund: json['canConfirmCashRefund'] as bool? ?? false,
      );
}
