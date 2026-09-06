import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/court.dart';
import '../../models/court_review.dart';
import '../../providers/court_review_provider.dart';
import '../../widgets/dialog_header.dart';

/// Read-only list of client reviews for one court, with the average at the top.
/// Reviews are written from the mobile app; the admin only monitors them here.
class CourtReviewsDialog extends StatefulWidget {
  final Court court;

  const CourtReviewsDialog({super.key, required this.court});

  @override
  State<CourtReviewsDialog> createState() => _CourtReviewsDialogState();
}

class _CourtReviewsDialogState extends State<CourtReviewsDialog> {
  List<CourtReview> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context
          .read<CourtReviewProvider>()
          .get(filter: {'courtId': widget.court.id, 'page': 1, 'pageSize': 100});
      if (!mounted) return;
      setState(() {
        _reviews = result.result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  double get _average => _reviews.isEmpty
      ? 0
      : _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _reviews.length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: dialogHeader(context, '${tr(context, 'Recenzije')} - ${widget.court.name}'),
      content: SizedBox(
        width: 460,
        height: 380,
        child: _buildBody(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr(context, 'Zatvori')),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_reviews.isEmpty) {
      return Center(child: Text(tr(context, 'Još nema recenzija za ovaj teren.')));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 6),
            Text(
              '${tr(context, 'Prosječna ocjena')}: ${_average.toStringAsFixed(1)} (${_reviews.length})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const Divider(height: 20),
        Expanded(
          child: ListView.separated(
            itemCount: _reviews.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (ctx, i) => _reviewTile(ctx, _reviews[i]),
          ),
        ),
      ],
    );
  }

  Widget _reviewTile(BuildContext context, CourtReview review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(
              5,
              (i) => Icon(
                i < review.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                review.userName ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Text(
              DateFormat('dd.MM.yyyy.').format(review.createdAt.toLocal()),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        if (review.comment != null && review.comment!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(review.comment!, style: const TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
