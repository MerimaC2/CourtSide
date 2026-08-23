import 'dart:convert';

import '../models/payment.dart';
import 'base_provider.dart';

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
}
