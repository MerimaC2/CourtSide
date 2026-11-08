import 'package:flutter_test/flutter_test.dart';

import 'package:courtside_mobile/models/reservation.dart';
import 'package:courtside_mobile/utils/util.dart';

Reservation _reservation(int id, String date, String startTime, {String? cancelDeadlineAt}) =>
    Reservation.fromJson({
      'id': id,
      'date': date,
      'startTime': startTime,
      'endTime': '23:00:00',
      'status': 'Confirmed',
      'cancelDeadlineAt': cancelDeadlineAt,
    });

void main() {
  test('reservations on the same day are ordered by start time', () {
    final reservations = [
      _reservation(1, '2026-11-07', '18:00:00'),
      _reservation(2, '2026-11-08', '09:00:00'),
      _reservation(3, '2026-11-07', '12:00:00'),
    ];

    final ascending = reservations.toList()..sort((a, b) => a.compareStart(b));
    final descending = reservations.toList()..sort((a, b) => b.compareStart(a));

    expect(ascending.map((r) => r.id), [3, 1, 2]);
    expect(descending.map((r) => r.id), [2, 1, 3]);
  });

  test('cancel deadline shows the venue time the server sent, whatever the device zone', () {
    // The device running the test has one fixed zone; offsets far from it would have shifted
    // the time if it were converted to the device's zone.
    for (final offset in ['+01:00', '+02:00', '+05:45', '-08:00']) {
      final reservation = _reservation(1, '2026-11-07', '12:00:00',
          cancelDeadlineAt: '2026-11-06T12:00:00$offset');
      expect(formatDisplayDateTime(reservation.cancelDeadlineAt!), '06.11.2026. 12:00',
          reason: offset);
    }
  });

  test('missing cancel deadline stays empty', () {
    expect(_reservation(1, '2026-11-07', '12:00:00').cancelDeadlineAt, isNull);
  });
}
