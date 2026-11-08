import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_stripe/flutter_stripe.dart' show SetupPaymentSheetParameters, Stripe;
import 'package:http/http.dart' show ClientException;

import '../models/payment.dart';
import 'base_provider.dart';
import 'api_error.dart';

class PaymentProvider extends BaseProvider<Payment> {
  PaymentProvider() : super('payments');

  @override
  Payment fromJson(Map<String, dynamic> json) => Payment.fromJson(json);

  Future<PaymentIntent> createIntent(int reservationId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$reservationId/intent'),
      headers: createHeaders(),
    );
    isValidResponse(response);
    return PaymentIntent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Asks the server to check the payment's status with Stripe and finalize it if it
  /// succeeded. Called right after the payment sheet closes, so the reservation is
  /// marked paid without depending on the webhook.
  Future<Payment> verify(int reservationId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$reservationId/verify'),
      headers: createHeaders(),
    );
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Payment> payCash(int reservationId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$reservationId/cash'),
      headers: createHeaders(),
    );
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Takes the card payment through Stripe's payment sheet and returns what the server says
  /// about it. The sheet closing is only the client's view of things; with automatic payment
  /// methods the charge can still be in flight, so callers must show the verified status
  /// rather than assume success.
  ///
  /// A cancelled sheet or a declined card surfaces as Stripe's own exception; a sheet that
  /// finished but could not be checked with the server as [PaymentVerificationFailed].
  Future<Payment> payWithStripe(int reservationId) async {
    final intent = await createIntent(reservationId);
    Stripe.publishableKey = intent.publishableKey;
    await Stripe.instance.applySettings();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: intent.clientSecret,
        merchantDisplayName: 'CourtSide',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
    try {
      return await verify(reservationId);
    } catch (e) {
      // An unreachable server surfaces as a socket error meant for developers; the user only
      // needs to know that the status will follow (the server settles the payment with Stripe).
      final unreachable = e is ClientException || e is SocketException || e is TimeoutException;
      throw PaymentVerificationFailed(
          reservationId,
          unreachable
              ? 'Server trenutno nije dostupan, pa plaćanje još nije potvrđeno. Status ćete vidjeti u Mojim rezervacijama.'
              : describeError(e));
    }
  }
}

/// The payment sheet finished but the server could not be asked what happened; carries the
/// server's explanation so the user is told why the status is still unknown.
class PaymentVerificationFailed implements Exception {
  final int reservationId;
  final String message;

  PaymentVerificationFailed(this.reservationId, this.message);
}
