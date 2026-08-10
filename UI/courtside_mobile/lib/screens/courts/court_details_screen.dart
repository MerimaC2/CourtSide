import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/court.dart';
import '../../providers/court_provider.dart';
import '../../utils/util.dart';
import '../reservations/availability_screen.dart';

class CourtDetailsScreen extends StatefulWidget {
  final Court court;

  const CourtDetailsScreen({super.key, required this.court});

  @override
  State<CourtDetailsScreen> createState() => _CourtDetailsScreenState();
}

class _CourtDetailsScreenState extends State<CourtDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Implicit signal for the recommender; failure here shouldn't block the screen.
    context.read<CourtProvider>().logView(widget.court.id).catchError((_) {});
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
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_tennis, color: kPrimaryColor, size: 48),
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
            const SizedBox(height: 16),
            _infoRow(Icons.payments_outlined, 'Cijena po satu', formatPrice(court.pricePerHour)),
            if (court.sportCenterName != null && court.sportCenterName!.isNotEmpty)
              _infoRow(Icons.location_on_outlined, 'Lokacija', court.sportCenterName!),
            _infoRow(
              Icons.circle,
              'Status',
              court.isActive ? 'Aktivan' : 'Neaktivan',
              iconColor: court.isActive ? kPrimaryColor : Colors.grey,
            ),
            if (court.description != null && court.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Opis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(court.description!, style: TextStyle(color: Colors.grey.shade800)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Provjeri dostupnost'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AvailabilityScreen(court: court)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? Colors.grey.shade600),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: Colors.grey.shade700)),
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
