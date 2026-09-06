/// Returned by POST /api/payments/{reservationId}/intent — everything the Stripe
/// Flutter SDK needs to present the native payment sheet for this reservation.
class PaymentIntent {
  final String clientSecret;
  final String publishableKey;
  final int amount;
  final String currency;

  PaymentIntent({
    required this.clientSecret,
    required this.publishableKey,
    required this.amount,
    required this.currency,
  });

  factory PaymentIntent.fromJson(Map<String, dynamic> json) => PaymentIntent(
        clientSecret: json['clientSecret'] as String? ?? '',
        publishableKey: json['publishableKey'] as String? ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        currency: json['currency'] as String? ?? 'BAM',
      );
}

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

  /// Raw processor status from a verification call, e.g. `processing` when the money is still
  /// on its way. Closing the payment sheet does not by itself mean the card was charged.
  final String? processorStatus;

  /// Whether the payment reached a state that will not change on its own.
  final bool isFinal;

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
    this.processorStatus,
    this.isFinal = false,
  });

  bool get isPaid => status == 'Completed';
  bool get isFailed => status == 'Failed';

  /// The charge was accepted but has not settled yet, so "paid" would be a lie.
  bool get isProcessing => !isPaid && !isFailed;

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
        processorStatus: json['processorStatus'] as String?,
        isFinal: json['isFinal'] as bool? ?? false,
      );
}
