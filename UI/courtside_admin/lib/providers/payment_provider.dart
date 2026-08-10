import 'dart:convert';

import '../models/payment.dart';
import 'base_provider.dart';

class PaymentProvider extends BaseProvider<Payment> {
  PaymentProvider() : super('payments');

  @override
  Payment fromJson(Map<String, dynamic> json) => Payment.fromJson(json);

  Future<Payment> getForReservation(int reservationId) => getById(reservationId);

  Future<Payment> payCash(int reservationId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$reservationId/cash'),
      headers: createHeaders(),
    );
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Payment?> refund(int reservationId) async {
    final response = await http.post(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$reservationId/refund'),
      headers: createHeaders(),
    );
    isValidResponse(response);
    if (response.body.isEmpty) return null;
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
