import 'package:flutter/material.dart';

import '../l10n/translations.dart';

/// Page navigation under a list: total count on the left, page controls on the right.
///
/// Every admin list pages through the same server-side API, so they share one widget —
/// the page size, the arithmetic and the labels stay identical wherever records are listed.
class Pager extends StatelessWidget {
  /// Records per page. The API caps a page at 100, so a list must never ask for more than
  /// it can receive; ten keeps the table readable on a laptop screen.
  static const int pageSize = 10;

  final int page;
  final int totalCount;
  final ValueChanged<int> onPageChanged;

  const Pager({
    super.key,
    required this.page,
    required this.totalCount,
    required this.onPageChanged,
  });

  /// How many pages [totalCount] records span; always at least one so the label reads "1 / 1"
  /// rather than "1 / 0" on an empty list.
  static int pageCount(int totalCount) =>
      totalCount <= 0 ? 1 : (totalCount + pageSize - 1) ~/ pageSize;

  @override
  Widget build(BuildContext context) {
    final totalPages = pageCount(totalCount);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text('${tr(context, 'Ukupno')}: $totalCount',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const Spacer(),
          IconButton(
            tooltip: tr(context, 'Prethodna stranica'),
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
          ),
          Text('${tr(context, 'Stranica')} $page / $totalPages'),
          IconButton(
            tooltip: tr(context, 'Sljedeća stranica'),
            icon: const Icon(Icons.chevron_right),
            onPressed: page < totalPages ? () => onPageChanged(page + 1) : null,
          ),
        ],
      ),
    );
  }
}
