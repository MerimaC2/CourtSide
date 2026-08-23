import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:courtside_mobile/l10n/translations.dart';
import 'package:courtside_mobile/utils/app_locale.dart';

/// Renders [text] through [tr] with English selected and returns what is shown.
Future<String> _englishFor(WidgetTester tester, String text) async {
  SharedPreferences.setMockInitialValues({'app_language': 'en'});
  final locale = LocaleProvider();
  await locale.load();
  late String shown;
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleProvider>.value(
      value: locale,
      child: Builder(
        builder: (context) {
          shown = tr(context, text);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return shown;
}

void main() {
  testWidgets('recommender explanations are translated', (tester) async {
    expect(
      await _englishFor(tester, 'Korisnici sa sličnim rezervacijama često biraju ovaj teren.'),
      'Users with similar bookings often choose this court.',
    );
    expect(
      await _englishFor(tester, 'Najpopularniji teren u zadnjih 30 dana.'),
      'Most popular court in the last 30 days.',
    );
  });

  testWidgets('notification bodies keep their reservation number', (tester) async {
    expect(
      await _englishFor(tester, 'Vaša rezervacija 6AD8 je kreirana i čeka potvrdu.'),
      'Your reservation 6AD8 has been created and is awaiting confirmation.',
    );
    expect(
      await _englishFor(tester, 'Rezervacija FFD2 je otkazana. Razlog: Spriječen dolazak.'),
      'Reservation FFD2 has been cancelled. Reason: Spriječen dolazak.',
    );
    expect(
      await _englishFor(tester, 'Gotovinsko plaćanje za rezervaciju 2B3E je evidentirano.'),
      'Cash payment for reservation 2B3E has been recorded.',
    );
  });

  testWidgets('unknown text is left untouched rather than breaking', (tester) async {
    expect(await _englishFor(tester, 'Neprevedeni tekst'), 'Neprevedeni tekst');
  });
}
