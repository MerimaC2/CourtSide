import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment.dart';
import '../../models/reservation.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/util.dart';

/// Shows full reservation details with admin actions (confirm/cancel).
/// Pops with `true` if the reservation was changed, so the caller can refresh its list.
class ReservationDetailDialog extends StatefulWidget {
  final Reservation reservation;

  const ReservationDetailDialog({super.key, required this.reservation});

  @override
  State<ReservationDetailDialog> createState() => _ReservationDetailDialogState();
}

class _ReservationDetailDialogState extends State<ReservationDetailDialog> {
  late Reservation _reservation;
  Payment? _payment;
  bool _busy = false;
  bool _loadingPayment = true;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
    _loadPayment();
  }

  Future<void> _loadPayment() async {
    try {
      final payment = await context.read<PaymentProvider>().getForReservation(_reservation.id);
      if (mounted) setState(() => _payment = payment);
    } catch (_) {
      // No payment record yet, or fetch failed — payment section just stays hidden.
    } finally {
      if (mounted) setState(() => _loadingPayment = false);
    }
  }

  Future<void> _payCash() async {
    setState(() => _busy = true);
    try {
      final payment = await context.read<PaymentProvider>().payCash(_reservation.id);
      if (!mounted) return;
      setState(() => _payment = payment);
      showSuccess(context, 'Uplata gotovinom je evidentirana.');
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refund() async {
    setState(() => _busy = true);
    try {
      final payment = await context.read<PaymentProvider>().refund(_reservation.id);
      if (!mounted) return;
      if (payment != null) setState(() => _payment = payment);
      showSuccess(context, 'Refund je pokrenut.');
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final updated = await context.read<ReservationProvider>().confirm(_reservation.id);
      if (!mounted) return;
      setState(() => _reservation = updated);
      showSuccess(context, 'Rezervacija je potvrđena.');
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otkazivanje rezervacije'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Razlog otkazivanja'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Nazad')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(reasonController.text.trim()),
            child: const Text('Otkaži rezervaciju'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await context.read<ReservationProvider>().cancel(_reservation.id, reason);
      if (!mounted) return;
      setState(() => _reservation = updated);
      showSuccess(context, 'Rezervacija je otkazana.');
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reservation;
    return AlertDialog(
      title: Text(r.reservationNumber),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Status', r.status),
              _row('Klijent', r.clientName ?? '-'),
              _row('Kontakt telefon', r.contactPhone),
              _row('Teren', r.courtName ?? '-'),
              if (r.sportCenterName != null) _row('Sportski centar', r.sportCenterName!),
              _row('Datum', formatDisplayDate(r.date)),
              _row('Termin', r.timeRange),
              _row('Iznos', formatPrice(r.totalPrice)),
              _row('Način plaćanja', r.paymentMethod ?? '-'),
              _row('Status plaćanja', r.paymentStatus ?? '-'),
              if (r.note != null && r.note!.isNotEmpty) _row('Napomena', r.note!),
              if (r.cancellationReason != null && r.cancellationReason!.isNotEmpty)
                _row('Razlog otkazivanja', r.cancellationReason!),
              const Divider(height: 24),
              _buildPaymentSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Zatvori'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          if (_payment != null &&
              _payment!.method == 'Cash' &&
              _payment!.status == 'Pending')
            OutlinedButton(onPressed: _payCash, child: const Text('Označi kao plaćeno')),
          if (_payment != null && _payment!.status == 'Completed')
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: _refund,
              child: const Text('Refundiraj'),
            ),
          if (r.isActive)
            TextButton(
              onPressed: _cancel,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Otkaži'),
            ),
          if (r.status == 'Pending')
            FilledButton(onPressed: _confirm, child: const Text('Potvrdi')),
        ],
      ],
    );
  }

  Widget _buildPaymentSection() {
    if (_loadingPayment) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final payment = _payment;
    if (payment == null) {
      return Text('Nema podataka o plaćanju.', style: TextStyle(color: Colors.grey.shade600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Plaćanje', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _row('Iznos', formatPrice(payment.amount)),
        _row('Status', payment.status),
        if (payment.paidAt != null) _row('Plaćeno', payment.paidAt.toString()),
        if (payment.refundedAmount != null)
          _row('Refundirano', formatPrice(payment.refundedAmount)),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
