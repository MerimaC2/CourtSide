import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/translations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/authorization.dart';
import '../../utils/util.dart';
import '../../widgets/language_toggle.dart';
import '../auth/login_screen.dart';
import '../courts/courts_screen.dart';
import '../news/news_screen.dart';
import '../reference/reference_data_screen.dart';
import '../reports/reports_screen.dart';
import '../reservations/reservations_screen.dart';
import '../schedule/schedule_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  List<_Section> _sections(BuildContext context) => [
        _Section(tr(context, 'Tereni'), Icons.sports_tennis_outlined),
        _Section(tr(context, 'Raspored'), Icons.calendar_month_outlined),
        _Section(tr(context, 'Rezervacije'), Icons.event_note_outlined),
        _Section(tr(context, 'Izvještaji'), Icons.picture_as_pdf_outlined),
        _Section(tr(context, 'Obavijesti'), Icons.campaign_outlined),
        _Section(tr(context, 'Referentni podaci'), Icons.tune_outlined),
      ];

  Future<void> _logout() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
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
          const LanguageToggle(),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Center(child: Text(Authorization.displayName)),
          ),
          IconButton(
            tooltip: tr(context, 'Odjava'),
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
            destinations: _sections(context)
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
                CourtsScreen(isActive: _selectedIndex == 0),
                ScheduleScreen(isActive: _selectedIndex == 1),
                ReservationsScreen(isActive: _selectedIndex == 2),
                const ReportsScreen(),
                const NewsScreen(),
                ReferenceDataScreen(isActive: _selectedIndex == 5),
              ],
            ),
          ),
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
