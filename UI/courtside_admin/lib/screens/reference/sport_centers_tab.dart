import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/city.dart';
import '../../models/sport_center.dart';
import '../../providers/base_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/sport_center_provider.dart';
import '../../utils/util.dart';
import '../../widgets/pager.dart';
import 'sport_center_form_dialog.dart';
import '../../providers/api_error.dart';

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
  int _page = 1;
  int _totalCount = 0;

  /// Identifies the newest load. Two loads can overlap (a pager click while a search is
  /// still running); only the newest answer is applied, so the rows always match the pager.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SportCentersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadCities();
      _load();
    }
  }

  /// The cities behind the form's dropdown. They are not paged and change rarely, so they are
  /// fetched when the tab opens rather than on every page turn.
  Future<void> _loadCities() async {
    try {
      final cities = await context
          .read<CityProvider>()
          .get(filter: {'page': 1, 'pageSize': BaseProvider.maxPageSize});
      if (mounted) setState(() => _cities = cities.result);
    } catch (_) {
      // Leaves the dropdown empty, which already disables the "add" button with a tooltip.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// A new search is a different result set, so paging starts over.
  Future<void> _resetAndLoad() {
    _page = 1;
    return _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    // A retry after the API was unreachable must bring the dropdown data back as well.
    if (_cities.isEmpty) _loadCities();
    setState(() {
      _loading = true;
      _error = null;
    });
    final sportCenterProvider = context.read<SportCenterProvider>();
    try {
      final filter = <String, dynamic>{
        'page': _page,
        'pageSize': Pager.pageSize,
        if (_searchController.text.trim().isNotEmpty)
          'searchTerm': _searchController.text.trim(),
      };
      final sportCenters = await sportCenterProvider.get(filter: filter);
      if (!mounted || token != _loadToken) return;
      if (sportCenters.result.isEmpty && _page > 1) {
        // The last record on this page was deleted; fall back to the first page.
        _page = 1;
        return await _load();
      }
      setState(() {
        _sportCenters = sportCenters.result;
        _totalCount = sportCenters.count;
      });
    } catch (e) {
      if (mounted && token == _loadToken) {
        final message = describeError(e);
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted && token == _loadToken) setState(() => _loading = false);
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
      // Lists are newest first, so after adding a record the list returns to the first page,
      // where the new record appears; an edit reloads the current page.
      sportCenter == null ? _resetAndLoad() : _load();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
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
      if (mounted) showError(context, describeError(e));
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
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward), onPressed: _resetAndLoad),
                  ),
                  onSubmitted: (_) => _resetAndLoad(),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: _cities.isEmpty ? tr(context, 'Prvo dodajte grad.') : '',
                child: FilledButton.icon(
                  onPressed: _cities.isEmpty ? null : () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, 'Dodaj sportski centar')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
          if (_error == null && _totalCount > 0)
            Pager(
              page: _page,
              totalCount: _totalCount,
              onPageChanged: (page) {
                setState(() => _page = page);
                _load();
              },
            ),
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
