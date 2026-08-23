import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../l10n/translations.dart';
import '../../models/sport_center.dart';
import '../../providers/report_provider.dart';
import '../../providers/sport_center_provider.dart';
import '../../utils/app_locale.dart';
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
    final language = context.read<LocaleProvider>().language == AppLanguage.en ? 'en' : 'bs';
    try {
      final bytes = await reportProvider.getReservationsReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        sportCenterId: _sportCenterId,
        language: language,
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
          content: Text(trMessage(context, 'Izvještaj je sačuvan.')),
          backgroundColor: kPrimaryColor,
          action: SnackBarAction(
            label: trMessage(context, 'Otvori'),
            textColor: Colors.white,
            onPressed: () => _openReport(file.path),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// Hands the saved file to the shell so it opens in the default PDF viewer.
  /// The plain Windows path is passed rather than a `file:` URI, which the shell
  /// resolves directly. If no viewer can be launched the path is shown instead, so
  /// the report is still findable.
  Future<void> _openReport(String path) async {
    var opened = false;
    try {
      opened = await launchUrlString(path);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${trMessage(context, 'Izvještaj je sačuvan u:')} $path'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'Izvještaj o rezervacijama'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            tr(context, 'Sažetak po statusu, ostvareni prihod i pregled rezervacija za odabrani period.'),
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
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: _sportCenterId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: tr(context, 'Sportski centar')),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(tr(context, 'Svi centri'))),
                    ..._sportCenters.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis))),
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
                    label: Text(tr(context, 'Generiši i sačuvaj PDF')),
                  ),
          ),
        ],
      ),
    );
  }
}
