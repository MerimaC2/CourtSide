import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show FailureCode, StripeException;
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/reservation.dart';
import '../../providers/base_provider.dart';
import '../../providers/court_review_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../../widgets/dialog_header.dart';
import '../../providers/api_error.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Reservation> _reservations = [];
  bool _loading = true;
  String? _error;

  /// The reservation whose card payment is under way, so a second payment cannot be started
  /// while the payment sheet is open.
  int? _payingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<ReservationProvider>()
          .getMine(filter: {'page': 1, 'pageSize': BaseProvider.maxPageSize});
      if (!mounted) return;
      setState(() => _reservations = result.result);
    } catch (e) {
      if (mounted) {
        final message = describeError(e);
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Reservation> get _active {
    final list = _reservations.where((r) => r.isActive).toList()
      ..sort((a, b) => a.compareStart(b));
    return list;
  }

  List<Reservation> get _history {
    final list = _reservations.where((r) => !r.isActive).toList()
      ..sort((a, b) => b.compareStart(a));
    return list;
  }

  Future<void> _cancel(Reservation reservation) async {
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
    try {
      await context.read<ReservationProvider>().cancel(reservation.id, reason);
      if (!mounted) return;
      showSuccess(context, 'Rezervacija je otkazana.');
      _load();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  /// Same card flow as the booking form. The outcome shown is what the server verified, so
  /// the reservation is reported as paid only once its payment is completed.
  Future<void> _payByCard(Reservation reservation) async {
    setState(() => _payingId = reservation.id);
    try {
      final payment = await context.read<PaymentProvider>().payWithStripe(reservation.id);
      if (!mounted) return;
      if (payment.isPaid) {
        showSuccess(context, 'Plaćeno online');
      } else if (payment.isFailed) {
        showError(context, 'Plaćanje nije uspjelo — rezervacija je neplaćena');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trMessage(context, 'Plaćanje je u obradi')}. '
                '${trMessage(context, 'Konačan status plaćanja vidjet ćete u Mojim rezervacijama.')}'),
          ),
        );
      }
    } on PaymentVerificationFailed catch (e) {
      // The sheet closed normally, so the card may have been charged; only the check with
      // the server failed, which leaves the outcome unknown rather than failed.
      if (!mounted) return;
      // An expired session has already sent the user to the login screen.
      if (!Authorization.isLoggedIn) {
        showError(context, 'Sesija je istekla. Prijavite se ponovo.');
        return;
      }
      showError(context, '${trMessage(context, 'Plaćanje je u obradi')}: ${trMessage(context, e.message)}');
    } on StripeException catch (e) {
      if (mounted) {
        // Closing the sheet is the user's own choice; Stripe's (English) note about it adds nothing.
        final detail = e.error.code == FailureCode.Canceled
            ? ''
            : ' (${e.error.localizedMessage ?? e.error.code})';
        showError(context,
            '${trMessage(context, 'Plaćanje nije završeno')}$detail. ${trMessage(context, 'Rezervacija je i dalje neplaćena.')}');
      }
    } catch (e) {
      final message = describeError(e);
      if (mounted) {
        // Preparing a new payment found the earlier card payment already collected and recorded it.
        if (message == 'Rezervacija je već plaćena.') {
          showSuccess(context, 'Plaćeno online');
        } else {
          showError(context, message);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _payingId = null);
        // An expired session has already sent the user to the login screen.
        if (Authorization.isLoggedIn) _load();
      }
    }
  }

  Future<void> _rate(Reservation reservation) async {
    int rating = 5;
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: dialogHeader(ctx, tr(ctx, 'Ocijeni teren')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = starIndex),
                    icon: Icon(
                      starIndex <= rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(labelText: tr(ctx, 'Komentar (opciono)')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr(ctx, 'Odustani')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr(ctx, 'Sačuvaj')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<CourtReviewProvider>().submit(
            reservationId: reservation.id,
            rating: rating,
            comment: commentController.text.trim(),
          );
      if (!mounted) return;
      showSuccess(context, 'Hvala na ocjeni!');
      _load();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Moje rezervacije')),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [Tab(text: tr(context, 'Aktivne')), Tab(text: tr(context, 'Historija'))],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_active, canCancelSection: true),
                      _buildList(_history, canCancelSection: false),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(tr(context, 'Pokušaj ponovo'))),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Reservation> items, {required bool canCancelSection}) {
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(tr(context, 'Nema rezervacija.'))),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _reservationCard(items[i], canCancelSection: canCancelSection),
    );
  }

  Widget _reservationCard(Reservation r, {required bool canCancelSection}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.courtName ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                _statusBadge(context, r.status),
              ],
            ),
            if (r.sportCenterName != null && r.sportCenterName!.isNotEmpty)
              Text(r.sportCenterName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Text(formatDisplayDate(r.date)),
                const SizedBox(width: 14),
                const Icon(Icons.access_time, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Text(r.timeRange),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(formatPrice(r.totalPrice),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimaryColor)),
                ),
                if (r.paymentStatus != null) _paymentBadge(context, r.paymentStatus!),
              ],
            ),
            if (r.isActive && r.canPayOnline) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _payingId == r.id
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton.icon(
                        onPressed: _payingId == null ? () => _payByCard(r) : null,
                        icon: const Icon(Icons.credit_card, size: 18, color: kPrimaryColor),
                        label: Text(tr(context, 'Plati karticom'),
                            style: const TextStyle(color: kPrimaryColor)),
                      ),
              ),
            ],
            if (canCancelSection) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: r.canCancel
                    ? TextButton.icon(
                        onPressed: () => _cancel(r),
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                        label: Text(tr(context, 'Otkaži'), style: const TextStyle(color: Colors.red)),
                      )
                    : Text(
                        _cancelClosedText(context, r),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
              ),
            ],
            if (r.status == 'Completed' && !r.hasReview) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _rate(r),
                  icon: const Icon(Icons.star_outline, size: 18, color: kPrimaryColor),
                  label: Text(tr(context, 'Ocijeni'), style: const TextStyle(color: kPrimaryColor)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Why the booking can no longer be cancelled. The server decides the rule; the deadline it
  /// sends is shown as an exact moment, with the general 24h rule as the fallback.
  String _cancelClosedText(BuildContext context, Reservation r) {
    final deadline = r.cancelDeadlineAt;
    if (deadline == null) return tr(context, 'Otkazivanje nije moguće manje od 24h prije termina.');
    return '${tr(context, 'Otkazivanje je bilo moguće do')} ${formatDisplayDateTime(deadline)}.';
  }

  /// The state of the money, shown next to the price so an online payment that is still in
  /// progress or was refunded is visible without opening anything.
  Widget _paymentBadge(BuildContext context, String status) {
    final Color color = switch (status) {
      'Completed' => kPrimaryColor,
      'Failed' || 'RefundFailed' => Colors.red,
      'Refunded' => Colors.blueGrey,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(translatePaymentStatus(context, status),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statusBadge(BuildContext context, String status) {
    final Color color = switch (status) {
      'Confirmed' => kPrimaryColor,
      'Pending' => Colors.orange,
      'Cancelled' => Colors.red,
      'Completed' => Colors.blueGrey,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(translateReservationStatus(context, status),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
