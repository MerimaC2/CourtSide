import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/news.dart';
import '../../providers/base_provider.dart';
import '../../providers/news_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../../widgets/pager.dart';
import 'news_form_dialog.dart';
import '../../providers/api_error.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _searchController = TextEditingController();
  List<News> _items = [];
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
      final result = await context.read<NewsProvider>().get(filter: filter);
      if (!mounted || token != _loadToken) return;
      if (result.result.isEmpty && _page > 1) {
        // The last record on this page was deleted; fall back to the first page.
        _page = 1;
        return await _load();
      }
      setState(() {
        _items = result.result;
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

  Future<void> _openForm({News? news}) async {
    final result = await showDialog<NewsFormResult>(
      context: context,
      builder: (_) => NewsFormDialog(news: news),
    );
    if (result == null) return;
    if (!mounted) return;
    final provider = context.read<NewsProvider>();
    try {
      final News saved;
      if (news == null) {
        saved = await provider.addAsync(result.toBody());
      } else {
        saved = await provider.updateAsync(news.id, result.toBody());
      }
      // The image is a second request, so success is reported only once both have landed —
      // otherwise a rejected image would follow a "saved" message.
      if (result.imageBytes != null) {
        await provider.uploadImage(
          saved.id,
          result.imageBytes!,
          result.imageFilename ?? 'photo.jpg',
          result.imageContentType ?? 'image/jpeg',
        );
      }
      if (mounted) {
        showSuccess(context, news == null ? 'Obavijest je dodana.' : 'Obavijest je ažurirana.');
      }
      // Lists are newest first, so after adding a record the list returns to the first page,
      // where the new record appears; an edit reloads the current page.
      news == null ? _resetAndLoad() : _load();
    } catch (e) {
      if (mounted) showError(context, describeError(e));
    }
  }

  Future<void> _delete(News news) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, 'Brisanje obavijesti')),
        content: Text('${trMessage(ctx, 'Obrisati obavijest')} "${news.title}"?'),
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
      await context.read<NewsProvider>().deleteById(news.id);
      if (mounted) showSuccess(context, 'Obavijest je obrisana.');
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
                    hintText: tr(context, 'Pretraga obavijesti...'),
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
                label: Text(tr(context, 'Dodaj obavijest')),
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
    if (_items.isEmpty) {
      return Center(child: Text(tr(context, 'Nema obavijesti.')));
    }
    return SingleChildScrollView(
      child: DataTable(
        columns: [
          DataColumn(label: Text('')),
          DataColumn(label: Text(tr(context, 'Naslov'))),
          DataColumn(label: Text(tr(context, 'Datum objave'))),
          DataColumn(label: Text(tr(context, 'Akcije'))),
        ],
        rows: _items.map((news) {
          return DataRow(cells: [
            DataCell(ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 40,
                child: news.hasImage
                    ? Image.network(
                        '${BaseProvider.baseUrl}news/${news.id}/image',
                        headers: {'Authorization': 'Bearer ${Authorization.token}'},
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _thumbnailPlaceholder(),
                      )
                    : _thumbnailPlaceholder(),
              ),
            )),
            DataCell(Text(news.title)),
            DataCell(Text(formatDisplayDate(formatApiDate(news.publishedAt)))),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: tr(context, 'Uredi'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _openForm(news: news),
                ),
                IconButton(
                  tooltip: tr(context, 'Obriši'),
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () => _delete(news),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _thumbnailPlaceholder() => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 18),
      );
}
