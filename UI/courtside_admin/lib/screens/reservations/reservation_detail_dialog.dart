import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reservation.dart';
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
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
