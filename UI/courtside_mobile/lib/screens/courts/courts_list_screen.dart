import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/city.dart';
import '../../models/court.dart';
import '../../models/sport.dart';
import '../../providers/city_provider.dart';
import '../../providers/court_provider.dart';
import '../../providers/sport_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../auth/login_screen.dart';
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
  int? _sportId;
  int? _cityId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final sportProvider = context.read<SportProvider>();
    final cityProvider = context.read<CityProvider>();
    try {
      final sports = await sportProvider.get(filter: {'Page': 1, 'PageSize': 100});
      final cities = await cityProvider.get(filter: {'Page': 1, 'PageSize': 100});
      if (!mounted) return;
      setState(() {
        _sports = sports.result;
        _cities = cities.result;
      });
    } catch (_) {
      // Filters are optional; ignore load failures here.
    }
    await _loadCourts();
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
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() {
    Authorization.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tereni'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Moje rezervacije',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
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
              hintText: 'Pretraga terena...',
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
                  decoration: const InputDecoration(
                      labelText: 'Sport', contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Svi sportovi')),
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
                  decoration: const InputDecoration(
                      labelText: 'Grad', contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Svi gradovi')),
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
              ElevatedButton(onPressed: _loadCourts, child: const Text('Pokušaj ponovo')),
            ],
          ),
        ),
      );
    }
    if (_courts.isEmpty) {
      return const Center(child: Text('Nema terena za zadane filtere.'));
    }
    return RefreshIndicator(
      onRefresh: _loadCourts,
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
        leading: CircleAvatar(
          backgroundColor: kPrimaryColor.withValues(alpha: 0.12),
          child: const Icon(Icons.sports_tennis, color: kPrimaryColor),
        ),
        title: Text(court.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [court.sportName, court.sportCenterName]
              .where((e) => e != null && e.isNotEmpty)
              .join(' • '),
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
}
