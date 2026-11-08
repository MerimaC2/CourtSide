import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:courtside_admin/models/payment.dart';
import 'package:courtside_admin/models/reservation.dart';
import 'package:courtside_admin/providers/payment_provider.dart';
import 'package:courtside_admin/screens/reservations/reservation_detail_dialog.dart';
import 'package:courtside_admin/utils/app_locale.dart';

/// A reservation with no payment record, without touching the network.
class _NoPaymentProvider extends PaymentProvider {
  @override
  Future<Payment> getForReservation(int reservationId) async => throw Exception('Nije pronađeno.');
}

Reservation _cancelled(String reason) => Reservation(
      id: 1,
      reservationNumber: 'RZ-20261106100000-ABCD',
      clientId: 1,
      courtId: 1,
      date: '2026-11-06',
      startTime: '10:00:00',
      endTime: '11:00:00',
      totalPrice: 30,
      status: 'Cancelled',
      contactName: 'Klijent',
      contactPhone: '061111111',
      cancellationReason: reason,
      isPaid: false,
      canConfirm: false,
    );

Future<void> _showDetailInEnglish(WidgetTester tester, Reservation reservation) async {
  SharedPreferences.setMockInitialValues({'app_language': 'en'});
  final locale = LocaleProvider();
  await locale.load();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: locale),
        ChangeNotifierProvider<PaymentProvider>(create: (_) => _NoPaymentProvider()),
      ],
      child: MaterialApp(home: Scaffold(body: ReservationDetailDialog(reservation: reservation))),
    ),
  );
  await tester.pumpAndSettle();
}

Payment _payment(
  String status, {
  String method = 'Cash',
  String? stripePaymentIntentId,
  String? refundFailureReason,
  bool canConfirmCashRefund = false,
}) =>
    Payment(
      reservationId: 1,
      method: method,
      amount: 30,
      currency: 'BAM',
      status: status,
      stripePaymentIntentId: stripePaymentIntentId,
      refundFailureReason: refundFailureReason,
      canConfirmCashRefund: canConfirmCashRefund,
    );

void main() {
  test('a settled refund is reported as done', () {
    final notice = refundNoticeFor(_payment('Refunded', method: 'Stripe', stripePaymentIntentId: 'pi_1'));
    expect(notice?.kind, RefundNoticeKind.success);
    expect(notice?.message, 'Povrat je izvršen.');
    expect(notice?.detail, isNull);
  });

  test('an online refund still at the processor is reported as started, not done', () {
    final notice = refundNoticeFor(
        _payment('RefundPending', method: 'Stripe', stripePaymentIntentId: 'pi_1'));
    expect(notice?.kind, RefundNoticeKind.info);
    expect(notice?.message,
        'Povrat je pokrenut kod platnog provajdera — status će se ažurirati kada ga potvrdi.');
  });

  test('a cash refund waits for the administrator to confirm the hand-back', () {
    final notice = refundNoticeFor(_payment('RefundPending', canConfirmCashRefund: true));
    expect(notice?.kind, RefundNoticeKind.info);
    expect(notice?.message, 'Povrat je odobren — potvrdite ga kada novac bude vraćen klijentu.');
  });

  test('a card payment without a processor reference is refunded manually', () {
    final notice =
        refundNoticeFor(_payment('RefundPending', method: 'Stripe', canConfirmCashRefund: true));
    expect(notice?.kind, RefundNoticeKind.info);
    expect(notice?.message, 'Povrat je odobren — potvrdite ga kada novac bude vraćen klijentu.');
  });

  test('a cash payment that once had a card attempt is still refunded manually', () {
    final notice = refundNoticeFor(_payment('RefundPending',
        stripePaymentIntentId: 'pi_abandoned', canConfirmCashRefund: true));
    expect(notice?.kind, RefundNoticeKind.info);
    expect(notice?.message, 'Povrat je odobren — potvrdite ga kada novac bude vraćen klijentu.');
  });

  test('a failed refund is reported as failed, with the reason', () {
    final notice = refundNoticeFor(_payment('RefundFailed',
        method: 'Stripe',
        stripePaymentIntentId: 'pi_1',
        refundFailureReason: 'Online plaćanje nije dostupno (Stripe nije konfigurisan).'));
    expect(notice?.kind, RefundNoticeKind.error);
    expect(notice?.message, 'Povrat nije uspio');
    expect(notice?.detail, 'Online plaćanje nije dostupno (Stripe nije konfigurisan).');
  });

  test('nothing is reported when no refund is under way', () {
    expect(refundNoticeFor(null), isNull);
    expect(refundNoticeFor(_payment('Completed')), isNull);
    expect(refundNoticeFor(_payment('Pending')), isNull);
  });

  testWidgets('the reason the system records on an unconfirmed reservation is translated',
      (WidgetTester tester) async {
    await _showDetailInEnglish(tester, _cancelled('Rezervacija nije potvrđena prije početka termina.'));
    expect(find.text('The reservation was not confirmed before the slot started.'), findsOneWidget);
  });

  testWidgets('a cancellation reason typed by a person is shown as it was written',
      (WidgetTester tester) async {
    await _showDetailInEnglish(tester, _cancelled('Spriječen dolazak zbog poslovnih obaveza.'));
    expect(find.text('Spriječen dolazak zbog poslovnih obaveza.'), findsOneWidget);
  });
}
