import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../models/payment.dart';
import '../../models/reservation.dart';
import '../../utils/util.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Reservation reservation;

  /// What the server verified about the card payment; null when paying cash on arrival.
  final Payment? payment;

  const BookingConfirmationScreen({super.key, required this.reservation, this.payment});

  /// Only a payment the server confirmed as completed may be shown as paid — closing the
  /// payment sheet is not proof that the card was charged.
  String get _paymentLabel {
    if (payment == null) return 'Plaćanje pri dolasku (gotovina)';
    if (payment!.isPaid) return 'Plaćeno online';
    if (payment!.isFailed) return 'Plaćanje nije uspjelo — rezervacija je neplaćena';
    return 'Plaćanje je u obradi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Potvrda rezervacije')),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: kPrimaryColor, size: 72),
            const SizedBox(height: 16),
            Text(tr(context, 'Rezervacija je uspješno kreirana!'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(reservation.reservationNumber,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row(context, 'Teren', reservation.courtName ?? '-'),
                    _row(context, 'Datum', formatDisplayDate(reservation.date)),
                    _row(context, 'Termin', reservation.timeRange),
                    _row(context, 'Iznos', formatPrice(reservation.totalPrice)),
                    _row(context, 'Plaćanje', trMessage(context, _paymentLabel)),
                  ],
                ),
              ),
            ),
            if (payment != null && payment!.isProcessing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tr(context, 'Konačan status plaćanja vidjet ćete u Mojim rezervacijama.'),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Text(tr(context, 'Nazad na terene')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tr(context, label), style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
