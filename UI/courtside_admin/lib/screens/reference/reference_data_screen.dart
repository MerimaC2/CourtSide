import 'package:flutter/material.dart';

import '../../l10n/translations.dart';
import '../../utils/util.dart';
import 'cities_tab.dart';
import 'countries_tab.dart';
import 'sport_centers_tab.dart';
import 'sports_tab.dart';

/// Admin management for shared reference data (sports, sport centers, cities, countries) —
/// grouped under a single tabbed screen since they're all simple lookup CRUD.
class ReferenceDataScreen extends StatefulWidget {
  /// Whether this is the currently selected section (see [CourtsScreen.isActive]).
  final bool isActive;

  const ReferenceDataScreen({super.key, this.isActive = true});

  @override
  State<ReferenceDataScreen> createState() => _ReferenceDataScreenState();
}

class _ReferenceDataScreenState extends State<ReferenceDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Each tab reloads when it becomes the visible one, so a country added on the
    // Countries tab is offered by the Cities form without leaving the screen.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabIndex != _tabController.index) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: kPrimaryColor,
          tabs: [
            Tab(text: tr(context, 'Sportovi')),
            Tab(text: tr(context, 'Sportski centri')),
            Tab(text: tr(context, 'Gradovi')),
            Tab(text: tr(context, 'Države')),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SportsTab(isActive: widget.isActive && _tabIndex == 0),
              SportCentersTab(isActive: widget.isActive && _tabIndex == 1),
              CitiesTab(isActive: widget.isActive && _tabIndex == 2),
              CountriesTab(isActive: widget.isActive && _tabIndex == 3),
            ],
          ),
        ),
      ],
    );
  }
}
