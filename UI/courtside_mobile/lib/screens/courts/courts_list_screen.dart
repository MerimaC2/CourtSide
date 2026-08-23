import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../models/city.dart';
import '../../models/court.dart';
import '../../models/recommendation.dart';
import '../../models/sport.dart';
import '../../providers/auth_provider.dart';
import '../../providers/base_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/court_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/sport_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../../widgets/language_toggle.dart';
import '../auth/login_screen.dart';
import '../news/news_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../reservations/my_reservations_screen.dart';
import 'court_details_screen.dart';

class CourtsListScreen extends StatefulWidget {
  const CourtsListScreen({super.key});

  @override
  State<CourtsListScreen> createState() => _CourtsListScreenState();
}

class _CourtsListScreenState extends State<CourtsListScreen> {
  final _searchController = TextEditingController();
  List<Sport> _sports = [];
  List<City> _cities = [];
  List<Court> _courts = [];
  List<Recommendation> _recommendations = [];
  int? _sportId;
  int? _cityId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
    final notificationProvider = context.read<NotificationProvider>();
    notificationProvider.refreshUnreadCount();
    notificationProvider.connect();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadFilters();
    await _loadCourts();
  }

  /// Pull-to-refresh reloads the filter data as well as the courts, so sports and
  /// cities added in the admin app appear without restarting the app.
  Future<void> _refreshAll() async {
    await _loadFilters();
    await _loadCourts();
  }

  Future<void> _loadFilters() async {
    final sportProvider = context.read<SportProvider>();
    final cityProvider = context.read<CityProvider>();
    final recommendationProvider = context.read<RecommendationProvider>();
    try {
      // Independent of each other — issue both requests before awaiting either.
      final sportsRequest = sportProvider.get(filter: {'Page': 1, 'PageSize': 100});
      final citiesRequest = cityProvider.get(filter: {'Page': 1, 'PageSize': 100});
      final sports = await sportsRequest;
      final cities = await citiesRequest;
      if (!mounted) return;
      setState(() {
        _sports = sports.result;
        _cities = cities.result;
        // A filter pointing at a sport/city that no longer exists would leave the
        // dropdown with a value that isn't among its items.
        if (_sportId != null && !_sports.any((s) => s.id == _sportId)) _sportId = null;
        if (_cityId != null && !_cities.any((c) => c.id == _cityId)) _cityId = null;
      });
    } catch (_) {
      // Filters are optional; ignore load failures here.
    }
    try {
      final recommendations = await recommendationProvider.getRecommendations(count: 3);
      if (!mounted) return;
      setState(() => _recommendations = recommendations);
    } catch (_) {
      // Recommendations are a bonus section; ignore load failures here.
    }
  }

  Future<void> _loadCourts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final courtProvider = context.read<CourtProvider>();
    try {
      final filter = <String, dynamic>{
        'Page': 1,
        'PageSize': 100,
        'IsActive': true,
        if (_searchController.text.trim().isNotEmpty)
          'SearchTerm': _searchController.text.trim(),
        if (_sportId != null) 'SportId': _sportId,
        if (_cityId != null) 'CityId': _cityId,
      };
      final result = await courtProvider.get(filter: filter);
      if (!mounted) return;
      setState(() => _courts = result.result);
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() => _error = trMessage(context, message));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    context.read<NotificationProvider>().disconnect();
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Tereni')),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        actions: [
          const LanguageToggle(),
          IconButton(
            tooltip: tr(context, 'Obavijesti'),
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NewsScreen()),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Notifikacije'),
            icon: Badge(
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Moj profil'),
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Moje rezervacije'),
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Odjava'),
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          if (_recommendations.isNotEmpty) _buildRecommendations(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(tr(context, 'Preporučeno za tebe'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _recommendations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _recommendationCard(_recommendations[i]),
          ),
        ),
        const Divider(height: 20),
      ],
    );
  }

  Widget _recommendationCard(Recommendation recommendation) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        color: kPrimaryColor.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourtDetailsScreen(
                court: Court(
                  id: recommendation.courtId,
                  name: recommendation.courtName,
                  sportId: 0,
                  sportName: recommendation.sportName,
                  sportCenterId: 0,
                  sportCenterName: recommendation.sportCenterName,
                  pricePerHour: recommendation.pricePerHour,
                  isActive: true,
                  primaryImageId: recommendation.primaryImageId,
                ),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recommendation.courtName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  [recommendation.sportName, recommendation.sportCenterName]
                      .where((e) => e != null && e.isNotEmpty)
                      .join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                Text(
                  tr(context, recommendation.reason),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 4),
                Text(formatPrice(recommendation.pricePerHour),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: tr(context, 'Pretraga terena...'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _loadCourts,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _loadCourts(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _sportId,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: tr(context, 'Sport'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(tr(context, 'Svi sportovi'))),
                    ..._sports.map((s) =>
                        DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) {
                    setState(() => _sportId = v);
                    _loadCourts();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _cityId,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: tr(context, 'Grad'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text(tr(context, 'Svi gradovi'))),
                    ..._cities.map((c) =>
                        DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) {
                    setState(() => _cityId = v);
                    _loadCourts();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadCourts, child: Text(tr(context, 'Pokušaj ponovo'))),
            ],
          ),
        ),
      );
    }
    if (_courts.isEmpty) {
      return Center(child: Text(tr(context, 'Nema terena za zadane filtere.')));
    }
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _courts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _courtCard(_courts[i]),
      ),
    );
  }

  Widget _courtCard(Court court) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 48,
            height: 48,
            child: court.primaryImageId != null
                ? Image.network(
                    '${BaseProvider.baseUrl}courts/${court.id}/images/${court.primaryImageId}',
                    headers: {'Authorization': 'Bearer ${Authorization.token}'},
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _courtIconFallback(),
                  )
                : _courtIconFallback(),
          ),
        ),
        title: Text(court.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              [court.sportName, court.sportCenterName]
                  .where((e) => e != null && e.isNotEmpty)
                  .join(' • '),
            ),
            if (court.averageRating != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 3),
                  Text(court.averageRating!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 3),
                  Text('(${court.reviewCount})',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ],
        ),
        trailing: Text(
          formatPrice(court.pricePerHour),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: kPrimaryColor),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CourtDetailsScreen(court: court)),
        ),
      ),
    );
  }

  Widget _courtIconFallback() => Container(
        color: kPrimaryColor.withValues(alpha: 0.12),
        alignment: Alignment.center,
        child: const Icon(Icons.sports_tennis, color: kPrimaryColor),
      );
}
