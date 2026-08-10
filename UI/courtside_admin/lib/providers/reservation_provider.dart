import 'dart:convert';

import '../models/reservation.dart';
import 'base_provider.dart';

class ReservationProvider extends BaseProvider<Reservation> {
  ReservationProvider() : super('reservations');

  @override
  Reservation fromJson(Map<String, dynamic> json) => Reservation.fromJson(json);

  Future<Reservation> confirm(int id) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/confirm'),
      headers: createHeaders(),
    );
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Reservation> cancel(int id, String reason) async {
    final response = await http.put(
      Uri.parse('${BaseProvider.baseUrl}$endpoint/$id/cancel'),
      headers: createHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    isValidResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
