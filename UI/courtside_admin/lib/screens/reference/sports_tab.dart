import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/sport.dart';
import '../../providers/sport_provider.dart';
import '../../utils/util.dart';
import '../../widgets/pager.dart';
import 'sport_form_dialog.dart';
import '../../providers/api_error.dart';

class SportsTab extends StatefulWidget {
  /// Whether this is the visible tab; the list reloads when it becomes visible.
  final bool isActive;

  const SportsTab({super.key, this.isActive = true});

  @override
  State<SportsTab> createState() => _SportsTabState();
}

class _SportsTabState extends State<SportsTab> {
  final _searchController = TextEditingController();
  List<Sport> _sports = [];
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
  void didUpdateWidget(covariant SportsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final filter = <String, dynamic>{
        'page': _page,
        'pageSize': Pager.pageSize,
        if (_searchController.text.trim().isNotEmpty)
          'searchTerm': _searchController.text.trim(),
      };
      final result = await context.read<SportProvider>().get(filter: filter);
      if (!mounted || token != _loadToken) return;
      if (result.result.isEmpty && _page > 1) {
        // The last record on this page was deleted; fall back to the first page.
        _page = 1;
        return await _load();
      }
      setState(() {
        _sports = result.result;
        _totalCount = result.count;
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

  Future<void> _openForm({Sport? sport}) async {
    final result = await showDialog<SportFormResult>(
      context: context,
      builder: (_) => SportFormDialog(sport: sport),
    );
    if (result == null) return;
    if (!mounted) return;
    final provider = context.read<SportProvider>();
    try {
      if (sport == null) {
        await provider.addAsync(result.toBody());
        if (mounted) showSuccess(context, 'Sport je dodan.');
      } else {
        await provider.updateAsync(sport.id, result.toBody());
        if (mounted) showSuccess(context, 'Sport je ažuriran.');
      }
      // Lists are newest first, so after adding a record the list returns to the first page,
      // where the new record appears; an edit reloads the current page.
      sport == null ? _resetAndLoad() : _load();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  Future<void> _delete(Sport sport) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Brisanje sporta')),
        content: Text('${trMessage(ctx, 'Obrisati sport')} "${sport.name}"?'),
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
      await context.read<SportProvider>().deleteById(sport.id);
      if (mounted) showSuccess(context, 'Sport je obrisan.');
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
                    hintText: tr(context, 'Pretraga sportova...'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward), onPressed: _resetAndLoad),
                  ),
                  onSubmitted: (_) => _resetAndLoad(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Dodaj sport')),
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
    if (_sports.isEmpty) {
      return Center(child: Text(tr(context, 'Nema sportova.')));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text(tr(context, 'Naziv'))),
          DataColumn(label: Text(tr(context, 'Opis'))),
          DataColumn(label: Text(tr(context, 'Akcije'))),
        ],
        rows: _sports.map((sport) {
          return DataRow(cells: [
            DataCell(Text(sport.name)),
            DataCell(Text(sport.description ?? '-')),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: tr(context, 'Uredi'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openForm(sport: sport),
                ),
                IconButton(
                  tooltip: tr(context, 'Obriši'),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _delete(sport),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}
