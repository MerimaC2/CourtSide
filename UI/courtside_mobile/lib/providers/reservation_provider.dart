import 'dart:convert';

import '../models/reservation.dart';
import '../models/search_result.dart';
import '../utils/util.dart';
import 'base_provider.dart';

class ReservationProvider extends BaseProvider<Reservation> {
  ReservationProvider() : super('reservations');

  @override
  Reservation fromJson(Map<String, dynamic> json) => Reservation.fromJson(json);

  Future<Reservation> create({
    required int courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String contactName,
    required String contactPhone,
    String? note,
    required String paymentMethod,
  }) {
    return addAsync({
      'courtId': courtId,
      'date': formatApiDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'contactName': contactName,
      'contactPhone': contactPhone,
      if (note != null && note.isNotEmpty) 'note': note,
      'paymentMethod': paymentMethod,
    });
  }

  Future<SearchResult<Reservation>> getMine({Map<String, dynamic>? filter}) async {
    var url = '${BaseProvider.baseUrl}$endpoint/mine';
    if (filter != null && filter.isNotEmpty) {
      url = '$url?${getQueryString(filter)}';
    }
    final response = await http.get(Uri.parse(url), headers: createHeaders());
    if (isValidResponse(response)) {
      final data = jsonDecode(response.body);
      final result = SearchResult<Reservation>();
      final List items = data is List ? data : (data['items'] as List? ?? const []);
      result.count = data is Map ? (data['totalCount'] as int? ?? items.length) : items.length;
      for (final item in items) {
        result.result.add(fromJson(item as Map<String, dynamic>));
      }
      return result;
    }
    throw Exception('Greška pri dohvatu rezervacija.');
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
