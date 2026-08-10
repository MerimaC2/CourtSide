import 'package:flutter/material.dart';

import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../auth/login_screen.dart';
import '../courts/courts_screen.dart';
import '../reservations/reservations_screen.dart';
import '../schedule/schedule_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  static const _sections = [
    _Section('Tereni', Icons.sports_tennis_outlined),
    _Section('Raspored', Icons.calendar_month_outlined),
    _Section('Rezervacije', Icons.event_note_outlined),
    _Section('Izvještaji', Icons.picture_as_pdf_outlined),
  ];

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
        title: const Text('CourtSide Admin'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: Text(Authorization.displayName)),
          ),
          IconButton(
            tooltip: 'Odjava',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: _sections
                .map((s) => NavigationRailDestination(
                      icon: Icon(s.icon),
                      label: Text(s.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const CourtsScreen(),
                const ScheduleScreen(),
                const ReservationsScreen(),
                _buildPlaceholder(_sections[3]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(_Section section) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(section.icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('${section.label} — uskoro', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _Section {
  final String label;
  final IconData icon;

  const _Section(this.label, this.icon);
}
