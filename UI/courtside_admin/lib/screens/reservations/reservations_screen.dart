import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reservation.dart';
import '../../providers/reservation_provider.dart';
import '../../utils/util.dart';
import 'reservation_detail_dialog.dart';

const _statuses = ['Pending', 'Confirmed', 'Cancelled', 'Completed'];

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
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
              hintText: 'Pretraga (broj, klijent)...',
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
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Svi statusi')),
              ..._statuses.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
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
          label: Text(_dateFrom == null ? 'Od datuma' : formatDisplayDate(formatApiDate(_dateFrom!))),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickDate(from: false),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(_dateTo == null ? 'Do datuma' : formatDisplayDate(formatApiDate(_dateTo!))),
        ),
        TextButton(onPressed: _clearFilters, child: const Text('Očisti filtere')),
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
            ElevatedButton(onPressed: _load, child: const Text('Pokušaj ponovo')),
          ],
        ),
      );
    }
    if (_reservations.isEmpty) {
      return const Center(child: Text('Nema rezervacija za zadane filtere.'));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Broj')),
          DataColumn(label: Text('Klijent')),
          DataColumn(label: Text('Teren')),
          DataColumn(label: Text('Datum')),
          DataColumn(label: Text('Termin')),
          DataColumn(label: Text('Iznos')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Plaćanje')),
          DataColumn(label: Text('')),
        ],
        rows: _reservations.map((r) {
          return DataRow(cells: [
            DataCell(Text(r.reservationNumber)),
            DataCell(Text(r.clientName ?? '-')),
            DataCell(Text(r.courtName ?? '-')),
            DataCell(Text(formatDisplayDate(r.date))),
            DataCell(Text(r.timeRange)),
            DataCell(Text(formatPrice(r.totalPrice))),
            DataCell(_statusChip(r.status)),
            DataCell(Text(r.paymentStatus ?? '-')),
            DataCell(
              IconButton(
                tooltip: 'Detalji',
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () => _openDetail(r),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _statusChip(String status) {
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
      child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
