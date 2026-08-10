import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/sport_center.dart';
import '../../providers/report_provider.dart';
import '../../providers/sport_center_provider.dart';
import '../../utils/util.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<SportCenter> _sportCenters = [];
  int? _sportCenterId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadSportCenters();
  }

  Future<void> _loadSportCenters() async {
    try {
      final result = await context
          .read<SportCenterProvider>()
          .get(filter: {'page': 1, 'pageSize': 100});
      if (mounted) setState(() => _sportCenters = result.result);
    } catch (_) {
      // Sport center filter is optional; ignore load failures here.
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _dateFrom : _dateTo) ?? now,
      firstDate: DateTime(now.year - 2),
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
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final reportProvider = context.read<ReportProvider>();
    try {
      final bytes = await reportProvider.getReservationsReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        sportCenterId: _sportCenterId,
      );
      final suggestedName =
          'rezervacije_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null) return;
      final file = File(location.path);
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Izvještaj je sačuvan.'),
          backgroundColor: kPrimaryColor,
          action: SnackBarAction(
            label: 'Otvori',
            textColor: Colors.white,
            onPressed: () => launchUrl(Uri.file(file.path)),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Izvještaj o rezervacijama',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Sažetak po statusu, ostvareni prihod i pregled rezervacija za odabrani period.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: true),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_dateFrom == null
                    ? 'Od datuma'
                    : formatDisplayDate(formatApiDate(_dateFrom!))),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: false),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                    _dateTo == null ? 'Do datuma' : formatDisplayDate(formatApiDate(_dateTo!))),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: _sportCenterId,
                  decoration: const InputDecoration(labelText: 'Sportski centar'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Svi centri')),
                    ..._sportCenters
                        .map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setState(() => _sportCenterId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 260,
            height: 48,
            child: _generating
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Generiši i sačuvaj PDF'),
                  ),
          ),
        ],
      ),
    );
  }
}
