import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../l10n/translations.dart';
import '../../models/sport_center.dart';
import '../../providers/base_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/sport_center_provider.dart';
import '../../utils/app_locale.dart';
import '../../utils/util.dart';
import '../../providers/api_error.dart';

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
  /// Which report is downloading right now (null = none). Only that card shows the
  /// spinner; the other button is disabled until the download finishes.
  String? _busyReport;

  @override
  void initState() {
    super.initState();
    _loadSportCenters();
  }

  Future<void> _loadSportCenters() async {
    try {
      final result = await context
          .read<SportCenterProvider>()
          .get(filter: {'page': 1, 'pageSize': BaseProvider.maxPageSize});
      if (mounted) setState(() => _sportCenters = result.result);
    } catch (_) {
      // Sport center filter is optional; ignore load failures here.
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    // The two ends bound each other, so a period that runs backwards cannot be picked at all.
    // Such a period matches nothing, and the empty report reads as "no bookings" rather than
    // as a mistake in the filter.
    final earliest = from ? DateTime(now.year - 2) : (_dateFrom ?? DateTime(now.year - 2));
    final latest = from ? (_dateTo ?? DateTime(now.year + 1)) : DateTime(now.year + 1);
    final current = (from ? _dateFrom : _dateTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(earliest)
          ? earliest
          : current.isAfter(latest)
              ? latest
              : current,
      firstDate: earliest,
      lastDate: latest,
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

  /// Downloads one of the two reports; [occupancy] picks which. Both share the
  /// same period/centre filters and the currently selected UI language.
  Future<void> _generate({bool occupancy = false}) async {
    setState(() => _busyReport = occupancy ? 'occupancy' : 'reservations');
    final reportProvider = context.read<ReportProvider>();
    final language = context.read<LocaleProvider>().language == AppLanguage.en ? 'en' : 'bs';
    final prefix = trMessage(context, occupancy ? 'popunjenost' : 'rezervacije');
    try {
      final bytes = occupancy
          ? await reportProvider.getOccupancyReport(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              sportCenterId: _sportCenterId,
              language: language,
            )
          : await reportProvider.getReservationsReport(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              sportCenterId: _sportCenterId,
              language: language,
            );
      final suggestedName =
          '${prefix}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
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
      if (mounted) showError(context, describeError(e));
    } finally {
      if (mounted) setState(() => _busyReport = null);
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
          Text(tr(context, 'Izvještaji'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            tr(context, 'Odaberite period i centar, zatim izvještaj koji želite preuzeti.'),
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
              // Clears the period and the sport centre filter, returning to a report over all time.
              if (_dateFrom != null || _dateTo != null || _sportCenterId != null)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _dateFrom = null;
                    _dateTo = null;
                    _sportCenterId = null;
                  }),
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(tr(context, 'Očisti filtere')),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _reportCard(
            title: tr(context, 'Izvještaj o rezervacijama'),
            description: tr(context,
                'Sažetak po statusu, ostvareni prihod i pregled rezervacija za odabrani period.'),
            busy: _busyReport == 'reservations',
            onGenerate: () => _generate(),
          ),
          const SizedBox(height: 12),
          _reportCard(
            title: tr(context, 'Popunjenost terena'),
            description: tr(context,
                'Najtraženiji termini i popunjenost svakog terena u odnosu na radno vrijeme.'),
            busy: _busyReport == 'occupancy',
            onGenerate: () => _generate(occupancy: true),
          ),
        ],
      ),
    );
  }

  /// One downloadable report: name, what it contains and its download button.
  /// [busy] marks the report currently downloading — only that card spins, while
  /// the other's button stays visible but disabled until the download finishes.
  Widget _reportCard({
    required String title,
    required String description,
    required bool busy,
    required VoidCallback onGenerate,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: kPrimaryColor, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 190,
              height: 44,
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _busyReport == null ? onGenerate : null,
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(tr(context, 'Preuzmi PDF')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
