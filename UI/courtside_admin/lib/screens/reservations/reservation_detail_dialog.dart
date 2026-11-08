import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/payment.dart';
import '../../models/reservation.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/util.dart';
import '../../widgets/dialog_header.dart';
import '../../providers/api_error.dart';

/// How a refund outcome is presented to the administrator.
enum RefundNoticeKind { success, info, error }

/// What to tell the administrator once a refund was asked for, chosen from the state the server
/// reports back: the money is returned, the payment provider still has to settle it, staff still
/// have to hand it back, or the attempt failed. [detail] is the server's failure reason, kept
/// apart from [message] so each is translated on its own. Returns null when the payment shows
/// no refund under way.
({RefundNoticeKind kind, String message, String? detail})? refundNoticeFor(Payment? payment) {
  if (payment == null) return null;
  // A manual refund (cash, or a card payment with no processor reference) is decided by the
  // server; a cash payment can still carry the id of an abandoned card attempt.
  final manual = payment.canConfirmCashRefund || payment.method == 'Cash';
  final online = !manual && payment.stripePaymentIntentId?.isNotEmpty == true;
  return switch (payment.status) {
    'Refunded' => (kind: RefundNoticeKind.success, message: 'Povrat je izvršen.', detail: null),
    'RefundPending' when manual => (
        kind: RefundNoticeKind.info,
        message: 'Povrat je odobren — potvrdite ga kada novac bude vraćen klijentu.',
        detail: null,
      ),
    'RefundPending' when online => (
        kind: RefundNoticeKind.info,
        message: 'Povrat je pokrenut kod platnog provajdera — status će se ažurirati kada ga potvrdi.',
        detail: null,
      ),
    'RefundFailed' => (
        kind: RefundNoticeKind.error,
        message: 'Povrat nije uspio',
        detail: payment.refundFailureReason,
      ),
    _ => null,
  };
}

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

  /// Asks the user to confirm an irreversible action before it runs.
  Future<bool> _confirmAction(String question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Potvrda')),
        content: Text(tr(ctx, question)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr(ctx, 'Odustani')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ctx, 'Potvrdi')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _payCash() async {
    if (!await _confirmAction('Označiti gotovinsku uplatu kao naplaćenu?')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final payment = await context.read<PaymentProvider>().payCash(_reservation.id);
      if (!mounted) return;
      setState(() => _payment = payment);
      showSuccess(context, 'Uplata gotovinom je evidentirana.');
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refund() async {
    if (!await _confirmAction('Pokrenuti povrat sredstava za ovu rezervaciju?')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final payment = await context.read<PaymentProvider>().refund(_reservation.id);
      if (!mounted) return;
      if (payment != null) setState(() => _payment = payment);
      _showRefundNotice(payment);
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reports a refund outcome in the style that matches it, so a refund that is only under
  /// way or has failed never reads as done.
  void _showRefundNotice(Payment? payment) {
    final notice = refundNoticeFor(payment);
    if (notice == null) return;
    switch (notice.kind) {
      case RefundNoticeKind.success:
        showSuccess(context, notice.message);
      case RefundNoticeKind.info:
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trMessage(context, notice.message))));
      case RefundNoticeKind.error:
        final detail = notice.detail;
        showError(
            context,
            detail == null || detail.isEmpty
                ? '${trMessage(context, notice.message)}.'
                : '${trMessage(context, notice.message)}: ${trMessage(context, detail)}');
    }
  }

  Future<void> _confirmCashRefund() async {
    // A card payment with no processor reference is refunded by hand as well, so the wording
    // follows the payment method.
    final cash = _payment?.method == 'Cash';
    if (!await _confirmAction(
        cash ? 'Da li je gotovina fizički vraćena klijentu?' : 'Da li je novac vraćen klijentu?')) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final payment = await context.read<PaymentProvider>().confirmCashRefund(_reservation.id);
      if (!mounted) return;
      setState(() => _payment = payment);
      showSuccess(context, cash ? 'Povrat gotovine je potvrđen.' : 'Ručni povrat je potvrđen.');
    } catch (e) {
      if (mounted) showError(context, describeError(e));
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
      // Which payment actions are allowed depends on the reservation status, so the
      // payment section is refreshed rather than left showing the previous options.
      await _loadPayment();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: dialogHeader(ctx, tr(ctx, 'Otkazivanje rezervacije')),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(labelText: tr(ctx, 'Razlog otkazivanja')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr(ctx, 'Nazad'))),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(reasonController.text.trim()),
            child: Text(tr(ctx, 'Otkaži rezervaciju')),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    if (!mounted) return;
    final paymentStatusBefore = _payment?.status;
    setState(() => _busy = true);
    try {
      final updated = await context.read<ReservationProvider>().cancel(_reservation.id, reason);
      if (!mounted) return;
      setState(() => _reservation = updated);
      showSuccess(context, 'Rezervacija je otkazana.');
      // Cancelling may have started a refund; the payment section must show that state, and
      // its outcome is reported the same way as a refund started by hand.
      await _loadPayment();
      if (!mounted) return;
      if (_payment?.status != paymentStatusBefore) _showRefundNotice(_payment);
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reservation;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: r.reservationNumber,
              child: Text(shortReservationNumber(r.reservationNumber)),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Zatvori'),
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(context, 'Status', translateReservationStatus(context, r.status)),
              _row(context, 'Klijent', r.clientName ?? '-'),
              _row(context, 'Kontakt telefon', r.contactPhone),
              _row(context, 'Teren', r.courtName ?? '-'),
              if (r.sportCenterName != null) _row(context, 'Sportski centar', r.sportCenterName!),
              _row(context, 'Datum', formatDisplayDate(r.date)),
              _row(context, 'Termin', r.timeRange),
              _row(context, 'Iznos', formatPrice(r.totalPrice)),
              _row(context, 'Način plaćanja',
                  r.paymentMethod != null ? translatePaymentMethod(context, r.paymentMethod!) : '-'),
              _row(context, 'Status plaćanja', switch (_payment?.status ?? r.paymentStatus) {
                final String status => translatePaymentStatus(context, status),
                null => '-',
              }),
              if (r.note != null && r.note!.isNotEmpty) _row(context, 'Napomena', r.note!),
              if (r.cancellationReason != null && r.cancellationReason!.isNotEmpty)
                _row(context, 'Razlog otkazivanja', trMessage(context, r.cancellationReason!)),
              const Divider(height: 24),
              _buildPaymentSection(),
            ],
          ),
        ),
      ),
      actions: [
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          // Payment actions (mark paid / refund) grouped separately from the
          // reservation-status actions that follow them.
          // Which payment actions are offered is decided by the server's payment rules, so a
          // button can never appear for a combination the API would refuse.
          if (_payment?.canCollectCash == true)
            OutlinedButton(onPressed: _payCash, child: Text(tr(context, 'Označi kao plaćeno'))),
          // Cancelling a paid reservation starts the refund on its own, so this button is the
          // recovery path: it appears when that refund never ran or came back failed.
          if (_payment?.canRefund == true)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: _refund,
              child: Text(tr(context,
                  _payment!.status == 'RefundFailed' ? 'Ponovi povrat' : 'Pokreni povrat')),
            ),
          if (_payment?.canConfirmCashRefund == true)
            FilledButton(
              onPressed: _confirmCashRefund,
              child: Text(tr(context,
                  _payment!.method == 'Cash' ? 'Potvrdi povrat gotovine' : 'Potvrdi ručni povrat')),
            ),
          if ((_payment?.canCollectCash == true ||
                  _payment?.canRefund == true ||
                  _payment?.canConfirmCashRefund == true) &&
              (r.isActive || r.status == 'Pending'))
            const SizedBox(width: 16),
          if (r.isActive)
            TextButton(
              onPressed: _cancel,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(tr(context, 'Otkaži')),
            ),
          if (r.status == 'Pending')
            Tooltip(
              message: r.canConfirm
                  ? ''
                  : tr(context, 'Potvrda više nije moguća — termin je već počeo ili je teren deaktiviran.'),
              child: FilledButton(
                onPressed: r.canConfirm ? _confirm : null,
                child: Text(tr(context, 'Potvrdi')),
              ),
            ),
          const SizedBox(width: 16),
        ],
        // Closing the dialog is always the right-most action, so it keeps the same
        // position no matter which status-dependent actions are shown next to it.
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr(context, 'Zatvori')),
        ),
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
      return Text(tr(context, 'Nema podataka o plaćanju.'),
          style: TextStyle(color: Colors.grey.shade600));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, 'Plaćanje'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        _row(context, 'Iznos', formatPrice(payment.amount)),
        _row(context, 'Status', translatePaymentStatus(context, payment.status)),
        if (payment.paidAt != null)
          _row(context, 'Plaćeno', formatDateTime(payment.paidAt!)),
        if (payment.refundRequestedAt != null && payment.refundedAt == null)
          _row(context, 'Povrat zatražen', formatDateTime(payment.refundRequestedAt!)),
        if (payment.refundedAmount != null)
          _row(context, 'Refundirano', formatPrice(payment.refundedAmount)),
        if (payment.refundedAt != null)
          _row(context, 'Povrat izvršen', formatDateTime(payment.refundedAt!)),
        if (payment.refundFailureReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tr(context, 'Razlog neuspjeha')}: ${tr(context, payment.refundFailureReason!)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(tr(context, label), style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
