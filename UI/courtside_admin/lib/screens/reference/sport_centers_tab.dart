import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/city.dart';
import '../../models/sport_center.dart';
import '../../providers/city_provider.dart';
import '../../providers/sport_center_provider.dart';
import '../../utils/util.dart';
import 'sport_center_form_dialog.dart';

class SportCentersTab extends StatefulWidget {
  /// Whether this is the visible tab; the list and the city dropdown behind the
  /// form reload when it becomes visible.
  final bool isActive;

  const SportCentersTab({super.key, this.isActive = true});

  @override
  State<SportCentersTab> createState() => _SportCentersTabState();
}

class _SportCentersTabState extends State<SportCentersTab> {
  final _searchController = TextEditingController();
  List<SportCenter> _sportCenters = [];
  List<City> _cities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SportCentersTab oldWidget) {
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
    final cityProvider = context.read<CityProvider>();
    final sportCenterProvider = context.read<SportCenterProvider>();
    try {
      final cities = await cityProvider.get(filter: {'page': 1, 'pageSize': 200});
      final filter = <String, dynamic>{
        'page': 1,
        'pageSize': 200,
        if (_searchController.text.trim().isNotEmpty)
          'searchTerm': _searchController.text.trim(),
      };
      final sportCenters = await sportCenterProvider.get(filter: filter);
      if (!mounted) return;
      setState(() {
        _cities = cities.result;
        _sportCenters = sportCenters.result;
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

  Future<void> _openForm({SportCenter? sportCenter}) async {
    final result = await showDialog<SportCenterFormResult>(
      context: context,
      builder: (_) => SportCenterFormDialog(sportCenter: sportCenter, cities: _cities),
    );
    if (result == null) return;
    if (!mounted) return;
    final provider = context.read<SportCenterProvider>();
    try {
      if (sportCenter == null) {
        await provider.addAsync(result.toBody());
        if (mounted) showSuccess(context, 'Sportski centar je dodan.');
      } else {
        await provider.updateAsync(sportCenter.id, result.toBody());
        if (mounted) showSuccess(context, 'Sportski centar je ažuriran.');
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(SportCenter sportCenter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Brisanje sportskog centra')),
        content: Text('${trMessage(ctx, 'Obrisati sportski centar')} "${sportCenter.name}"?'),
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
      await context.read<SportCenterProvider>().deleteById(sportCenter.id);
      if (mounted) showSuccess(context, 'Sportski centar je obrisan.');
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
                    hintText: tr(context, 'Pretraga sportskih centara...'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _cities.isEmpty ? null : () => _openForm(),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Dodaj sportski centar')),
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
    if (_sportCenters.isEmpty) {
      return Center(child: Text(tr(context, 'Nema sportskih centara.')));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(tr(context, 'Naziv'))),
          DataColumn(label: Text(tr(context, 'Grad'))),
          DataColumn(label: Text(tr(context, 'Adresa'))),
          DataColumn(label: Text(tr(context, 'Akcije'))),
        ],
        rows: _sportCenters.map((sportCenter) {
          return DataRow(cells: [
            DataCell(Text(sportCenter.name)),
            DataCell(Text(sportCenter.cityName ?? '-')),
            DataCell(Text(sportCenter.address)),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: tr(context, 'Uredi'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openForm(sportCenter: sportCenter),
                ),
                IconButton(
                  tooltip: tr(context, 'Obriši'),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _delete(sportCenter),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
