import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/court.dart';
import '../../models/court_review.dart';
import '../../providers/base_provider.dart';
import '../../providers/court_provider.dart';
import '../../providers/court_review_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../reservations/availability_screen.dart';

class CourtDetailsScreen extends StatefulWidget {
  final Court court;

  const CourtDetailsScreen({super.key, required this.court});

  @override
  State<CourtDetailsScreen> createState() => _CourtDetailsScreenState();
}

class _CourtDetailsScreenState extends State<CourtDetailsScreen> {
  List<CourtReview> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    // Implicit signal for the recommender; failure here shouldn't block the screen.
    context.read<CourtProvider>().logView(widget.court.id).catchError((_) {});
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final result = await context
          .read<CourtReviewProvider>()
          .get(filter: {'CourtId': widget.court.id, 'Page': 1, 'PageSize': 50});
      if (!mounted) return;
      setState(() {
        _reviews = result.result;
        _loadingReviews = false;
      });
    } catch (_) {
      // The court's own details stay usable even if its reviews can't be loaded.
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final court = widget.court;
    return Scaffold(
      appBar: AppBar(
        title: Text(court.name),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: court.primaryImageId != null
                    ? Image.network(
                        '${BaseProvider.baseUrl}courts/${court.id}/images/${court.primaryImageId}',
                        headers: {'Authorization': 'Bearer ${Authorization.token}'},
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
            ),
            const SizedBox(height: 20),
            Text(court.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              [court.sportName, court.sportCenterName]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(' • '),
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            if (court.averageRating != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(court.averageRating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Text('(${court.reviewCount})', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _infoRow(Icons.payments_outlined, 'Cijena po satu', formatPrice(court.pricePerHour)),
            if (court.sportCenterName != null && court.sportCenterName!.isNotEmpty)
              _infoRow(Icons.location_on_outlined, 'Lokacija', court.sportCenterName!),
            _infoRow(
              Icons.circle,
              'Status',
              tr(context, court.isActive ? 'Aktivan' : 'Neaktivan'),
              iconColor: court.isActive ? kPrimaryColor : Colors.grey,
            ),
            if (court.description != null && court.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(tr(context, 'Opis'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(court.description!, style: TextStyle(color: Colors.grey.shade800)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(tr(context, 'Provjeri dostupnost')),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AvailabilityScreen(court: court)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildReviews(),
          ],
        ),
      ),
    );
  }

  /// Reviews left by clients after a completed booking on this court.
  Widget _buildReviews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(tr(context, 'Recenzije'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (!_loadingReviews && _reviews.isNotEmpty)
              Text('(${_reviews.length})', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingReviews)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(tr(context, 'Još nema recenzija.'),
                style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (_, i) => _reviewTile(_reviews[i]),
          ),
      ],
    );
  }

  Widget _reviewTile(CourtReview review) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(
              5,
              (i) => Icon(i < review.rating ? Icons.star : Icons.star_border,
                  size: 15, color: Colors.amber),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                review.userName ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              formatDisplayDate(formatApiDate(review.createdAt)),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        if (review.comment != null && review.comment!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(review.comment!, style: TextStyle(color: Colors.grey.shade800)),
        ],
      ],
    );
  }

  Widget _imagePlaceholder() => Container(
        color: kPrimaryColor.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: const Icon(Icons.sports_tennis, color: kPrimaryColor, size: 48),
      );

  Widget _infoRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? Colors.grey.shade600),
          const SizedBox(width: 10),
          Text('${tr(context, label)}: ', style: TextStyle(color: Colors.grey.shade700)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
