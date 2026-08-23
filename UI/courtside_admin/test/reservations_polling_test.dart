import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:courtside_admin/models/reservation.dart';
import 'package:courtside_admin/models/search_result.dart';
import 'package:courtside_admin/providers/reservation_provider.dart';
import 'package:courtside_admin/screens/reservations/reservations_screen.dart';
import 'package:courtside_admin/utils/app_locale.dart';

/// Records how many times the screen queries the API, without touching the network.
class _RecordingReservationProvider extends ReservationProvider {
  int getCalls = 0;

  @override
  Future<SearchResult<Reservation>> get({Map<String, dynamic>? filter}) async {
    getCalls++;
    return SearchResult<Reservation>();
  }
}

Widget _host(_RecordingReservationProvider provider, {required bool isActive}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<ReservationProvider>.value(value: provider),
    ],
    child: MaterialApp(
      home: Scaffold(body: ReservationsScreen(isActive: isActive)),
    ),
  );
}

void main() {
  // The admin screens are laid out for a desktop window; the default 800x600 test
  // surface is narrower than any real one.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1600, 1000);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('visible tab keeps polling for newly created reservations',
      (WidgetTester tester) async {
    final provider = _RecordingReservationProvider();

    await tester.pumpWidget(_host(provider, isActive: true));
    await tester.pump();
    expect(provider.getCalls, 1, reason: 'initial load');

    // A reservation booked from the mobile app must appear without the
    // administrator searching or leaving the tab.
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(provider.getCalls, 2, reason: 'first poll tick');

    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(provider.getCalls, 3, reason: 'second poll tick');

    // Leaving the tab stops the polling so background sections stay idle.
    await tester.pumpWidget(_host(provider, isActive: false));
    await tester.pump(const Duration(seconds: 40));
    await tester.pump();
    expect(provider.getCalls, 3, reason: 'no polling while the tab is hidden');
  });

  testWidgets('returning to the tab reloads and resumes polling',
      (WidgetTester tester) async {
    final provider = _RecordingReservationProvider();

    await tester.pumpWidget(_host(provider, isActive: false));
    await tester.pump();
    final afterHiddenStart = provider.getCalls;

    await tester.pumpWidget(_host(provider, isActive: true));
    await tester.pump();
    expect(provider.getCalls, afterHiddenStart + 1, reason: 'reload on becoming visible');

    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(provider.getCalls, afterHiddenStart + 2, reason: 'polling resumed');
  });
}
