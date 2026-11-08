import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:courtside_mobile/utils/app_locale.dart';
import 'package:courtside_mobile/utils/validators.dart';

/// Runs [validate] with a context that has the (Bosnian) language selected.
Future<String?> _validate(WidgetTester tester, String? Function(BuildContext) validate) async {
  late String? result;
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: Builder(
        builder: (context) {
          result = validate(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return result;
}

void main() {
  const invalidPhone = 'Unesite ispravan broj telefona (6-20 cifara, dozvoljeni +, razmak, -).';

  testWidgets('phone with characters the server refuses gets the server message', (tester) async {
    expect(await _validate(tester, (c) => validatePhone(c, '(061) 234-567')), invalidPhone);
    expect(await _validate(tester, (c) => validatePhone(c, '061/234-567')), invalidPhone);
  });

  testWidgets('phone with too few digits says so', (tester) async {
    expect(await _validate(tester, (c) => validatePhone(c, '1-2-3-4-5')),
        'Broj telefona mora imati najmanje 6 cifara, npr. 061 234 567');
  });

  testWidgets('phone numbers the server accepts pass', (tester) async {
    expect(await _validate(tester, (c) => validatePhone(c, '061 234-567')), isNull);
    expect(await _validate(tester, (c) => validatePhone(c, '+387 61 234 567')), isNull);
  });

  testWidgets('optional phone may be left empty', (tester) async {
    expect(await _validate(tester, (c) => validatePhone(c, '', required: false)), isNull);
    expect(await _validate(tester, (c) => validatePhone(c, '')), 'Unesite broj telefona');
  });

  testWidgets('username follows the server rules and wording', (tester) async {
    expect(await _validate(tester, (c) => validateUsername(c, '  ')), 'Korisničko ime je obavezno.');
    expect(await _validate(tester, (c) => validateUsername(c, 'ab')),
        'Korisničko ime mora imati najmanje 3 znaka.');
    const invalidCharacters =
        'Korisničko ime smije sadržavati samo slova bez kvačica, brojeve i znakove - . _ @ +.';
    expect(await _validate(tester, (c) => validateUsername(c, 'mirzać')), invalidCharacters);
    expect(await _validate(tester, (c) => validateUsername(c, 'ime prezime')), invalidCharacters);
    expect(await _validate(tester, (c) => validateUsername(c, 'a.b_c-d@e+f1')), isNull);
  });
}
