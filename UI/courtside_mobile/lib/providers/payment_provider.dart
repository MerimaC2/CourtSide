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

  Future<Payment> payCash(int reservationId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$reservationId/cash'),
      headers: createHeaders(),
    );
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
