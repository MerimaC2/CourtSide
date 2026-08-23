import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/reservation.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/util.dart';
import 'reservation_detail_dialog.dart';

const _statuses = ['Pending', 'Confirmed', 'Cancelled', 'Completed'];

/// How often the visible list re-queries the API. Clients book from the mobile app
/// at any time, so the tab keeps itself current while the administrator is on it.
const _pollInterval = Duration(seconds: 15);

class ReservationsScreen extends StatefulWidget {
  /// Whether this screen is the currently selected tab. The admin shell keeps
  /// all tabs alive in an IndexedStack, so this is how we detect "the user
  /// switched back to Rezervacije" and reload — otherwise the list only ever
  /// loads once and goes stale (e.g. a reservation made on mobile wouldn't
  /// show up until a manual search).
  final bool isActive;

  const ReservationsScreen({super.key, this.isActive = true});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  final _searchController = TextEditingController();
  List<Reservation> _reservations = [];
  String? _status;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.isActive) _startPolling();
  }

  @override
  void didUpdateWidget(covariant ReservationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
      _startPolling();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _searchController.dispose();
    super.dispose();
  }

  /// Polling only runs while this is the visible tab, so background sections don't
  /// keep querying the API.
  void _startPolling() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _fetch(silent: true));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _load() => _fetch();

  /// A [silent] fetch is the background poll: it updates the list in place, without
  /// the loading spinner, and keeps whatever is already on screen if the request
  /// fails — a dropped poll shouldn't replace the table with an error.
  Future<void> _fetch({bool silent = false}) async {
    if (!mounted || _fetching) return;
    _fetching = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final reservationProvider = context.read<ReservationProvider>();
    try {
      final filter = <String, dynamic>{
        'page': 1,
        'pageSize': 200,
        if (_searchController.text.trim().isNotEmpty)
          'searchTerm': _searchController.text.trim(),
        if (_status != null) 'status': _status,
        if (_dateFrom != null) 'dateFrom': formatApiDate(_dateFrom!),
        if (_dateTo != null) 'dateTo': formatApiDate(_dateTo!),
      };
      final result = await reservationProvider.get(filter: filter);
      if (!mounted) return;
      setState(() => _reservations = result.result
        ..sort((a, b) => b.date.compareTo(a.date)));
    } catch (e) {
      if (mounted && !silent) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      _fetching = false;
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _status = null;
      _dateFrom = null;
      _dateTo = null;
    });
    _load();
  }

  Future<void> _openDetail(Reservation reservation) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => ReservationDetailDialog(reservation: reservation),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilters(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: tr(context, 'Pretraga (broj, klijent)...'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String?>(
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(tr(context, 'Svi statusi'))),
              ..._statuses.map((s) => DropdownMenuItem<String?>(
                  value: s, child: Text(translateReservationStatus(context, s)))),
            ],
            onChanged: (v) {
              setState(() => _status = v);
              _load();
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickDate(from: true),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(_dateFrom == null
              ? tr(context, 'Od datuma')
              : formatDisplayDate(formatApiDate(_dateFrom!))),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickDate(from: false),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(_dateTo == null
              ? tr(context, 'Do datuma')
              : formatDisplayDate(formatApiDate(_dateTo!))),
        ),
        TextButton(onPressed: _clearFilters, child: Text(tr(context, 'Očisti filtere'))),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(tr(context, 'Pokušaj ponovo'))),
          ],
        ),
      );
    }
    if (_reservations.isEmpty) {
      return Center(child: Text(tr(context, 'Nema rezervacija za zadane filtere.')));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(tr(context, 'Broj'))),
          DataColumn(label: Text(tr(context, 'Klijent'))),
          DataColumn(label: Text(tr(context, 'Teren'))),
          DataColumn(label: Text(tr(context, 'Datum'))),
          DataColumn(label: Text(tr(context, 'Termin'))),
          DataColumn(label: Text(tr(context, 'Iznos'))),
          const DataColumn(label: Text('Status')),
          DataColumn(label: Text(tr(context, 'Plaćanje'))),
          const DataColumn(label: Text('')),
        ],
        rows: _reservations.map((r) {
          return DataRow(cells: [
            DataCell(Tooltip(
              message: r.reservationNumber,
              child: Text(shortReservationNumber(r.reservationNumber)),
            )),
            DataCell(Text(r.clientName ?? '-')),
            DataCell(Text(r.courtName ?? '-')),
            DataCell(Text(formatDisplayDate(r.date))),
            DataCell(Text(r.timeRange)),
            DataCell(Text(formatPrice(r.totalPrice))),
            DataCell(_statusChip(context, r.status)),
            DataCell(Text(
                r.paymentStatus != null ? translatePaymentStatus(context, r.paymentStatus!) : '-')),
            DataCell(
              IconButton(
                tooltip: tr(context, 'Detalji'),
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () => _openDetail(r),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final color = switch (status) {
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
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
