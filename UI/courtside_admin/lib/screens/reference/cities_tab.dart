import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/city.dart';
import '../../models/country.dart';
import '../../providers/city_provider.dart';
import '../../providers/base_provider.dart';
import '../../providers/country_provider.dart';
import '../../utils/util.dart';
import '../../widgets/pager.dart';
import 'city_form_dialog.dart';
import '../../providers/api_error.dart';

class CitiesTab extends StatefulWidget {
  /// Whether this is the visible tab; the list and the country dropdown behind the
  /// form reload when it becomes visible.
  final bool isActive;

  const CitiesTab({super.key, this.isActive = true});

  @override
  State<CitiesTab> createState() => _CitiesTabState();
}

class _CitiesTabState extends State<CitiesTab> {
  final _searchController = TextEditingController();
  List<City> _cities = [];
  List<Country> _countries = [];
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
  void didUpdateWidget(covariant CitiesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadCountries();
      _load();
    }
  }

  /// The countries behind the form's dropdown. They are not paged and change rarely, so they
  /// are fetched when the tab opens rather than on every page turn.
  Future<void> _loadCountries() async {
    try {
      final countries = await context
          .read<CountryProvider>()
          .get(filter: {'page': 1, 'pageSize': BaseProvider.maxPageSize});
      if (mounted) setState(() => _countries = countries.result);
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
    if (_countries.isEmpty) _loadCountries();
    setState(() {
      _loading = true;
      _error = null;
    });
    final cityProvider = context.read<CityProvider>();
    try {
      final filter = <String, dynamic>{
        'page': _page,
        'pageSize': Pager.pageSize,
        if (_searchController.text.trim().isNotEmpty)
          'searchTerm': _searchController.text.trim(),
      };
      final cities = await cityProvider.get(filter: filter);
      if (!mounted || token != _loadToken) return;
      if (cities.result.isEmpty && _page > 1) {
        // The last record on this page was deleted; fall back to the first page.
        _page = 1;
        return await _load();
      }
      setState(() {
        _cities = cities.result;
        _totalCount = cities.count;
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

  Future<void> _openForm({City? city}) async {
    final result = await showDialog<CityFormResult>(
      context: context,
      builder: (_) => CityFormDialog(city: city, countries: _countries),
    );
    if (result == null) return;
    if (!mounted) return;
    final provider = context.read<CityProvider>();
    try {
      if (city == null) {
        await provider.addAsync(result.toBody());
        if (mounted) showSuccess(context, 'Grad je dodan.');
      } else {
        await provider.updateAsync(city.id, result.toBody());
        if (mounted) showSuccess(context, 'Grad je ažuriran.');
      }
      // Lists are newest first, so after adding a record the list returns to the first page,
      // where the new record appears; an edit reloads the current page.
      city == null ? _resetAndLoad() : _load();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  Future<void> _delete(City city) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Brisanje grada')),
        content: Text('${trMessage(ctx, 'Obrisati grad')} "${city.name}"?'),
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
      await context.read<CityProvider>().deleteById(city.id);
      if (mounted) showSuccess(context, 'Grad je obrisan.');
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
                    hintText: tr(context, 'Pretraga gradova...'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward), onPressed: _resetAndLoad),
                  ),
                  onSubmitted: (_) => _resetAndLoad(),
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: _countries.isEmpty ? tr(context, 'Prvo dodajte državu.') : '',
                child: FilledButton.icon(
                  onPressed: _countries.isEmpty ? null : () => _openForm(),
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, 'Dodaj grad')),
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
    if (_cities.isEmpty) {
      return Center(child: Text(tr(context, 'Nema gradova.')));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(tr(context, 'Naziv'))),
          DataColumn(label: Text(tr(context, 'Država'))),
          DataColumn(label: Text(tr(context, 'Poštanski broj'))),
          DataColumn(label: Text(tr(context, 'Akcije'))),
        ],
        rows: _cities.map((city) {
          return DataRow(cells: [
            DataCell(Text(city.name)),
            DataCell(Text(city.countryName ?? '-')),
            DataCell(Text(city.postalCode ?? '-')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: tr(context, 'Uredi'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openForm(city: city),
                ),
                IconButton(
                  tooltip: tr(context, 'Obriši'),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _delete(city),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
