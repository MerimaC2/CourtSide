import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/reservation.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/util.dart';

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
          .getMine(filter: {'page': 1, 'pageSize': 200});
      if (!mounted) return;
      setState(() => _reservations = result.result);
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Reservation> get _active {
    final list = _reservations.where((r) => r.isActive).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<Reservation> get _history {
    final list = _reservations.where((r) => !r.isActive).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _cancel(Reservation reservation) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Otkazivanje rezervacije')),
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
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
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
            Text(formatPrice(r.totalPrice),
                style: const TextStyle(fontWeight: FontWeight.w600, color: kPrimaryColor)),
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
                        tr(context, 'Otkazivanje nije moguće manje od 24h prije termina.'),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
              ),
            ],
          ],
        ),
      ),
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
