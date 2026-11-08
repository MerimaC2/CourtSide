import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/news.dart';
import '../../providers/base_provider.dart';
import '../../providers/news_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../../providers/api_error.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<News> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await context.read<NewsProvider>().get(filter: {'page': 1, 'pageSize': BaseProvider.maxPageSize});
      if (!mounted) return;
      setState(() => _items = result.result);
    } catch (e) {
      if (mounted) {
        final message = describeError(e);
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Obavijesti')),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: Text(tr(context, 'Pokušaj ponovo'))),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(child: Text(tr(context, 'Nema obavijesti.')))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _newsCard(_items[i]),
                      ),
                    ),
    );
  }

  Widget _newsCard(News news) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (news.hasImage)
            SizedBox(
              width: double.infinity,
              height: 140,
              child: Image.network(
                '${BaseProvider.baseUrl}news/${news.id}/image',
                headers: {'Authorization': 'Bearer ${Authorization.token}'},
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(news.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(formatDisplayDate(formatApiDate(news.publishedAt)),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 8),
                Text(news.text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
