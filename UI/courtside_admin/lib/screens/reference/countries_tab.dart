import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/country.dart';
import '../../providers/country_provider.dart';
import '../../utils/util.dart';
import 'country_form_dialog.dart';

class CountriesTab extends StatefulWidget {
  /// Whether this is the visible tab; the list reloads when it becomes visible.
  final bool isActive;

  const CountriesTab({super.key, this.isActive = true});

  @override
  State<CountriesTab> createState() => _CountriesTabState();
}

class _CountriesTabState extends State<CountriesTab> {
  final _searchController = TextEditingController();
  List<Country> _countries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CountriesTab oldWidget) {
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
    try {
      final filter = <String, dynamic>{
        'page': 1,
        'pageSize': 200,
        if (_searchController.text.trim().isNotEmpty)
          'searchTerm': _searchController.text.trim(),
      };
      final result = await context.read<CountryProvider>().get(filter: filter);
      if (!mounted) return;
      setState(() => _countries = result.result);
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Country? country}) async {
    final result = await showDialog<CountryFormResult>(
      context: context,
      builder: (_) => CountryFormDialog(country: country),
    );
    if (result == null) return;
    if (!mounted) return;
    final provider = context.read<CountryProvider>();
    try {
      if (country == null) {
        await provider.addAsync(result.toBody());
        if (mounted) showSuccess(context, 'Država je dodana.');
      } else {
        await provider.updateAsync(country.id, result.toBody());
        if (mounted) showSuccess(context, 'Država je ažurirana.');
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Country country) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Brisanje države')),
        content: Text('${trMessage(ctx, 'Obrisati državu')} "${country.name}"?'),
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
      await context.read<CountryProvider>().deleteById(country.id);
      if (mounted) showSuccess(context, 'Država je obrisana.');
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
                    hintText: tr(context, 'Pretraga država...'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _load),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Dodaj državu')),
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
    if (_countries.isEmpty) {
      return Center(child: Text(tr(context, 'Nema država.')));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(tr(context, 'Naziv'))),
          DataColumn(label: Text(tr(context, 'ISO kod'))),
          DataColumn(label: Text(tr(context, 'Akcije'))),
        ],
        rows: _countries.map((country) {
          return DataRow(cells: [
            DataCell(Text(country.name)),
            DataCell(Text(country.isoCode ?? '-')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: tr(context, 'Uredi'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openForm(country: country),
                ),
                IconButton(
                  tooltip: tr(context, 'Obriši'),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _delete(country),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
