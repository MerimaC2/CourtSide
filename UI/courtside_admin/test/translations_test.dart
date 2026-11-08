import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:courtside_admin/l10n/translations.dart';
import 'package:courtside_admin/utils/app_locale.dart';

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

/// Renders [text] through [trMessage] with English selected and returns what is shown.
Future<String> _englishMessageFor(WidgetTester tester, String text) async {
  SharedPreferences.setMockInitialValues({'app_language': 'en'});
  final locale = LocaleProvider();
  await locale.load();
  late String shown;
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleProvider>.value(
      value: locale,
      child: Builder(
        builder: (context) {
          shown = trMessage(context, text);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return shown;
}

Future<void> _expectEnglish(WidgetTester tester, Map<String, String> expected) async {
  for (final entry in expected.entries) {
    expect(await _englishFor(tester, entry.key), entry.value, reason: entry.key);
  }
}

void main() {
  testWidgets('refund failure reasons recorded by the server are translated', (tester) async {
    await _expectEnglish(tester, {
      'Platni provajder nije dostupan.': 'The payment provider is unavailable.',
      'Povrat nije pokrenut kod platnog provajdera.':
          'The refund was not started with the payment provider.',
      'Online plaćanje nije dostupno (Stripe nije konfigurisan).':
          'Online payment is unavailable (Stripe is not configured).',
    });
  });

  testWidgets('payment rule refusals are translated', (tester) async {
    await _expectEnglish(tester, {
      'Rezervacija je otkazana pa se na njoj može izvršiti samo povrat sredstava.':
          'The reservation is cancelled, so only a refund can be made on it.',
      'Rok za naknadnu evidenciju gotovinske uplate (7 dana) je istekao.':
          'The period for recording a cash payment afterwards (7 days) has expired.',
      'Termin je završen — online plaćanje više nije moguće, uplata se evidentira na terenu.':
          'The slot has ended — online payment is no longer possible; the payment is recorded at the court.',
      'Povrat je moguć samo za otkazanu rezervaciju. Prvo otkažite rezervaciju.':
          'A refund is only possible for a cancelled reservation. Cancel the reservation first.',
      'Nema gotovinskog povrata koji čeka potvrdu.': 'There is no cash refund awaiting confirmation.',
      'Ova radnja nije dozvoljena za trenutno stanje rezervacije i plaćanja.':
          'This action is not allowed in the current state of the reservation and payment.',
      'Plaćanje je u obradi — sačekajte potvrdu prije novog pokušaja.':
          'The payment is being processed — wait for confirmation before trying again.',
      'Rezervacija nema pokrenuto online plaćanje.': 'The reservation has no online payment started.',
    });
  });

  testWidgets('a refused reservation status change keeps both statuses', (tester) async {
    expect(
      await _englishFor(tester, "Nije moguća promjena statusa rezervacije sa 'Cancelled' na 'Confirmed'."),
      "The reservation status cannot be changed from 'Cancelled' to 'Confirmed'.",
    );
    expect(
      await _englishFor(tester, "Nije moguća promjena statusa rezervacije sa 'Completed' na 'Cancelled'."),
      "The reservation status cannot be changed from 'Completed' to 'Cancelled'.",
    );
    expect(
      await _englishFor(tester, "Nije moguća promjena statusa rezervacije sa 'Otkazana' na 'Potvrđena'."),
      "The reservation status cannot be changed from 'Cancelled' to 'Confirmed'.",
    );
  });

  testWidgets('court and schedule messages are translated', (tester) async {
    await _expectEnglish(tester, {
      'Naziv može imati najviše 120 znakova.': 'The name can be at most 120 characters long.',
      'Radno vrijeme mora biti navedeno (prazna lista znači da je teren zatvoren).':
          'Working hours must be provided (an empty list means the court is closed).',
      'Teren više nije aktivan — rezervaciju nije moguće potvrditi.':
          'The court is no longer active — the reservation cannot be confirmed.',
      'Teren ne radi tog dana pa nema šta blokirati.':
          'The court is closed that day, so there is nothing to block.',
    });
  });

  testWidgets('server validation messages are translated', (tester) async {
    await _expectEnglish(tester, {
      'Naziv centra je obavezan.': 'The sports center name is required.',
      'Adresa je obavezna.': 'The address is required.',
      'Odaberite grad.': 'Select a city.',
      'Geografska širina mora biti između -90 i 90.': 'Latitude must be between -90 and 90.',
      'Geografska dužina mora biti između -180 i 180.': 'Longitude must be between -180 and 180.',
      'Naziv terena je obavezan.': 'The court name is required.',
      'Odaberite sport.': 'Select a sport.',
      'Odaberite sportski centar.': 'Select a sports center.',
      'Cijena po satu mora biti veća od 0.': 'The price per hour must be greater than 0.',
      'Odaberite teren.': 'Select a court.',
      'Naslov je obavezan.': 'The title is required.',
      'Tekst obavijesti je obavezan.': 'The announcement text is required.',
      'Naziv države je obavezan.': 'The country name is required.',
      'ISO kod može imati najviše 3 znaka.': 'The ISO code can be at most 3 characters long.',
      'Naziv grada je obavezan.': 'The city name is required.',
      'Odaberite državu.': 'Select a country.',
      'Naziv sporta je obavezan.': 'The sport name is required.',
      'Korisničko ime je obavezno.': 'The username is required.',
      'Lozinka je obavezna.': 'The password is required.',
      'Korisničko ime smije sadržavati samo slova bez kvačica, brojeve i znakove - . _ @ +':
          'The username may contain only letters without diacritics, digits and the characters - . _ @ +',
      'Korisničko ime smije sadržavati samo slova bez kvačica, brojeve i znakove - . _ @ +.':
          'The username may contain only letters without diacritics, digits and the characters - . _ @ +.',
    });
  });

  testWidgets('a message of several lines is translated line by line', (tester) async {
    expect(
      await _englishMessageFor(tester, 'Naziv terena je obavezan.\nOdaberite sport.'),
      'The court name is required.\nSelect a sport.',
    );
    // A line with no entry, such as text a user typed, stays as it is.
    expect(
      await _englishMessageFor(
          tester, 'Spriječen dolazak.\nRezervacija nije potvrđena prije početka termina.'),
      'Spriječen dolazak.\nThe reservation was not confirmed before the slot started.',
    );
  });
}
