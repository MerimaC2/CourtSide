import 'package:flutter_test/flutter_test.dart';

import 'package:courtside_mobile/models/app_notification.dart';

Map<String, dynamic> _payload(Object? type) => {
      'id': 42,
      'title': 'Rezervacija potvrđena',
      'text': 'Vaša rezervacija 6AD8 je potvrđena.',
      'isRead': false,
      'type': type,
      'createdAt': '2026-11-06T10:15:00Z',
    };

void main() {
  test('type sent as the enum name is kept', () {
    final notification = AppNotification.fromJson(_payload('ReservationConfirmed'));

    expect(notification.type, 'ReservationConfirmed');
    expect(notification.id, 42);
    expect(notification.text, 'Vaša rezervacija 6AD8 je potvrđena.');
  });

  test('type sent as the enum value is mapped to its name', () {
    expect(AppNotification.fromJson(_payload(2)).type, 'ReservationConfirmed');
    expect(AppNotification.fromJson(_payload(1)).type, 'ReservationCreated');
    expect(AppNotification.fromJson(_payload(9)).type, 'PaymentRefundFailed');
  });

  test('missing or unknown type falls back to General', () {
    expect(AppNotification.fromJson(_payload(null)).type, 'General');
    expect(AppNotification.fromJson(_payload(99)).type, 'General');
  });
}
