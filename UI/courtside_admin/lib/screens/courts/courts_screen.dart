import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/court.dart';
import '../../models/sport.dart';
import '../../models/sport_center.dart';
import '../../providers/base_provider.dart';
import '../../providers/court_provider.dart';
import '../../providers/sport_center_provider.dart';
import '../../providers/sport_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import 'court_form_dialog.dart';

class CourtsScreen extends StatefulWidget {
  /// Whether this is the currently selected section. The admin shell keeps every
  /// section alive in an [IndexedStack], so courts and the sport/sport-centre lists
  /// behind the form dropdowns are reloaded whenever the section becomes visible.
  final bool isActive;

  const CourtsScreen({super.key, this.isActive = true});

  @override
  State<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends State<CourtsScreen> {
  final _searchController = TextEditingController();
  List<Court> _courts = [];
  List<Sport> _sports = [];
  List<SportCenter> _sportCenters = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CourtsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
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
    final sportProvider = context.read<SportProvider>();
    final sportCenterProvider = context.read<SportCenterProvider>();
    final courtProvider = context.read<CourtProvider>();
    try {
      final sports = await sportProvider.get(filter: {'page': 1, 'pageSize': 100});
      final sportCenters = await sportCenterProvider.get(filter: {'page': 1, 'pageSize': 100});
      final filter = <String, dynamic>{
        'page': 1,
        'pageSize': 200,
        if (_searchController.text.trim().isNotEmpty)
          'searchTerm': _searchController.text.trim(),
      };
      final courts = await courtProvider.get(filter: filter);
      if (!mounted) return;
      setState(() {
        _sports = sports.result;
        _sportCenters = sportCenters.result;
        _courts = courts.result;
      });
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Court? court}) async {
    final result = await showDialog<CourtFormResult>(
      context: context,
      builder: (_) => CourtFormDialog(
        court: court,
        sports: _sports,
        sportCenters: _sportCenters,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    final courtProvider = context.read<CourtProvider>();
    try {
      final Court saved;
      if (court == null) {
        saved = await courtProvider.addAsync(result.toBody());
        if (mounted) showSuccess(context, 'Teren je dodan.');
      } else {
        saved = await courtProvider.updateAsync(court.id, result.toBody());
        if (mounted) showSuccess(context, 'Teren je ažuriran.');
      }
      if (result.imageBytes != null) {
        await courtProvider.uploadImage(
          saved.id,
          result.imageBytes!,
          result.imageFilename ?? 'photo.jpg',
          result.imageContentType ?? 'image/jpeg',
        );
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Court court) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Brisanje terena')),
        content: Text('${trMessage(ctx, 'Obrisati teren')} "${court.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(ctx, 'Odustani'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr(ctx, 'Obriši')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await context.read<CourtProvider>().deleteById(court.id);
      if (mounted) showSuccess(context, 'Teren je obrisan.');
      _load();
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: tr(context, 'Pretraga terena...'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _load,
                    ),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: (_sports.isEmpty || _sportCenters.isEmpty)
                    ? tr(context, 'Prvo dodajte sport i sportski centar u Referentnim podacima.')
                    : '',
                child: FilledButton.icon(
                  onPressed:
                      (_sports.isEmpty || _sportCenters.isEmpty) ? null : () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, 'Dodaj teren')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
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
    if (_courts.isEmpty) {
      return Center(child: Text(tr(context, 'Nema terena.')));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text('')),
          DataColumn(label: Text(tr(context, 'Naziv'))),
          const DataColumn(label: Text('Sport')),
          DataColumn(label: Text(tr(context, 'Sportski centar'))),
          DataColumn(label: Text(tr(context, 'Cijena/h'))),
          const DataColumn(label: Text('Status')),
          DataColumn(label: Text(tr(context, 'Akcije'))),
        ],
        rows: _courts.map((court) {
          return DataRow(cells: [
            DataCell(_courtThumbnail(court)),
            DataCell(Text(court.name)),
            DataCell(Text(court.sportName ?? '-')),
            DataCell(Text(court.sportCenterName ?? '-')),
            DataCell(Text(formatPrice(court.pricePerHour))),
            DataCell(_statusChip(context, court.isActive)),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: tr(context, 'Uredi'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openForm(court: court),
                ),
                IconButton(
                  tooltip: tr(context, 'Obriši'),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _delete(court),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _courtThumbnail(Court court) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 40,
        height: 40,
        child: court.primaryImageId != null
            ? Image.network(
                '${BaseProvider.baseUrl}courts/${court.id}/images/${court.primaryImageId}',
                headers: {'Authorization': 'Bearer ${Authorization.token}'},
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _thumbnailPlaceholder(),
              )
            : _thumbnailPlaceholder(),
      ),
    );
  }

  Widget _thumbnailPlaceholder() => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 18),
      );

  Widget _statusChip(BuildContext context, bool isActive) {
    final color = isActive ? kPrimaryColor : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(tr(context, isActive ? 'Aktivan' : 'Neaktivan'),
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
