import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:courtside_admin/models/court.dart';
import 'package:courtside_admin/models/sport.dart';
import 'package:courtside_admin/models/sport_center.dart';
import 'package:courtside_admin/screens/courts/court_form_dialog.dart';
import 'package:courtside_admin/utils/app_locale.dart';

const _closedNote = 'Teren nema radno vrijeme — neće imati slobodnih termina.';
const _standardHoursButton = 'Standardno radno vrijeme (08–22, svaki dan)';

/// Opens the form from a button, the way the courts screen does, and hands back what it returns.
Widget _host({Court? court, required void Function(CourtFormResult?) onResult}) {
  return ChangeNotifierProvider(
    create: (_) => LocaleProvider(),
    child: MaterialApp(
      // The test font draws every glyph a full em wide, so 12-hour times ("10:00 PM") make a
      // weekday row wider than the dialog; 24-hour times keep it at the width real fonts give.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                onResult(await showDialog<CourtFormResult>(
                  context: context,
                  builder: (_) => CourtFormDialog(
                    court: court,
                    sports: [Sport(id: 1, name: 'Tenis')],
                    sportCenters: [
                      SportCenter(id: 1, name: 'Centar', address: 'Adresa 1', cityId: 1),
                    ],
                  ),
                ));
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

List<bool?> _dayStates(WidgetTester tester) =>
    tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).map((c) => c.value).toList();

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

  testWidgets('a new court starts closed until the standard hours are asked for',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(onResult: (_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(_dayStates(tester), List.filled(7, false));
    expect(find.text(_closedNote), findsOneWidget);

    await tester.ensureVisible(find.text(_standardHoursButton));
    await tester.tap(find.text(_standardHoursButton));
    await tester.pump();

    expect(_dayStates(tester), List.filled(7, true));
    expect(find.text(_closedNote), findsNothing);
  });

  testWidgets('a closed court can be saved and stays closed', (WidgetTester tester) async {
    CourtFormResult? result;
    final court = Court(
      id: 3,
      name: 'Teren 1',
      sportId: 1,
      sportCenterId: 1,
      pricePerHour: 20,
      isActive: true,
    );
    await tester.pumpWidget(_host(court: court, onResult: (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(_dayStates(tester), List.filled(7, false));
    expect(find.text(_closedNote), findsOneWidget);

    await tester.ensureVisible(find.text('Sačuvaj'));
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Teren 1');
    expect(result!.workingHours, isEmpty);
    expect(result!.toBody()['workingHours'], isEmpty);
  });
}
