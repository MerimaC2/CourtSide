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

/// Passes [text] through [trMessage] with English selected, as the snackbars do.
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

  testWidgets('popular-court explanation is translated', (tester) async {
    expect(
      await _englishFor(tester, 'Popularan teren u zadnjih 30 dana.'),
      'A popular court in the last 30 days.',
    );
  });

  testWidgets('manual refund notification keeps its reservation number', (tester) async {
    expect(
      await _englishFor(
          tester, 'Povrat za rezervaciju 7C1A je odobren — administrator će ga izvršiti ručno.'),
      'The refund for reservation 7C1A has been approved — an administrator will process it manually.',
    );
  });

  testWidgets('every notification title the server sends is translated', (tester) async {
    // Titles passed to NotificationService.CreateAsync by ReservationService and PaymentService.
    const titles = {
      'Rezervacija kreirana': 'Reservation created',
      'Rezervacija potvrđena': 'Reservation confirmed',
      'Rezervacija otkazana': 'Reservation cancelled',
      'Rezervacija završena': 'Reservation completed',
      'Plaćanje evidentirano': 'Payment recorded',
      'Plaćanje uspješno': 'Payment successful',
      'Povrat izvršen': 'Refund completed',
      'Povrat je pokrenut': 'Refund started',
      'Povrat nije uspio': 'Refund failed',
    };
    for (final entry in titles.entries) {
      expect(await _englishFor(tester, entry.key), entry.value);
    }
  });

  testWidgets('refund notification bodies keep their reservation number', (tester) async {
    expect(
      await _englishFor(tester, 'Povrat za rezervaciju 3F9B je izvršen.'),
      'The refund for reservation 3F9B has been completed.',
    );
    expect(
      await _englishFor(
          tester, 'Povrat za rezervaciju 3F9B je odobren — sredstva preuzimate na recepciji.'),
      'The refund for reservation 3F9B has been approved — you can collect the money at the reception.',
    );
    expect(
      await _englishFor(tester, 'Povrat za rezervaciju 3F9B je pokrenut kod platnog provajdera.'),
      'The refund for reservation 3F9B has been started with the payment provider.',
    );
    expect(
      await _englishFor(
          tester, 'Povrat za rezervaciju 3F9B nije uspio. Osoblje će vas kontaktirati.'),
      'The refund for reservation 3F9B failed. Our staff will contact you.',
    );
    expect(
      await _englishFor(tester, 'Izvršen je povrat za rezervaciju 3F9B.'),
      'A refund has been issued for reservation 3F9B.',
    );
  });

  testWidgets('remaining reservation notification bodies keep their reservation number',
      (tester) async {
    expect(
      await _englishFor(tester, 'Vaša rezervacija 9E21 je potvrđena.'),
      'Your reservation 9E21 has been confirmed.',
    );
    expect(
      await _englishFor(tester, 'Vaša rezervacija 9E21 je završena. Možete ocijeniti teren.'),
      'Your reservation 9E21 is complete. You can now rate the court.',
    );
    expect(
      await _englishFor(tester, 'Online plaćanje za rezervaciju 9E21 je zaprimljeno.'),
      'Online payment for reservation 9E21 has been received.',
    );
  });

  testWidgets('system cancellation reason is translated inside the notification body',
      (tester) async {
    expect(
      await _englishFor(tester,
          'Rezervacija 5D4C je otkazana. Razlog: Rezervacija nije potvrđena prije početka termina.'),
      'Reservation 5D4C has been cancelled. Reason: The reservation was not confirmed before the slot started.',
    );
  });

  testWidgets('card payment and sign-out messages are translated', (tester) async {
    expect(await _englishFor(tester, 'Plati karticom'), 'Pay by card');
    expect(await _englishFor(tester, 'Rezervacija je i dalje neplaćena.'),
        'The reservation is still unpaid.');
    expect(
      await _englishFor(tester, 'Odjava na serveru nije potvrđena — lokalna sesija je završena.'),
      'Sign-out was not confirmed by the server — the local session has ended.',
    );
  });

  testWidgets('server messages a client can trigger are translated', (tester) async {
    const messages = {
      'Korisničko ime smije sadržavati samo slova bez kvačica, brojeve i znakove - . _ @ +':
          'The username may only contain letters without diacritics, digits and the characters - . _ @ +',
      'Korisničko ime smije sadržavati samo slova bez kvačica, brojeve i znakove - . _ @ +.':
          'The username may only contain letters without diacritics, digits and the characters - . _ @ +.',
      'Korisničko ime je obavezno.': 'Username is required.',
      'Korisničko ime mora imati najmanje 3 znaka.': 'The username must be at least 3 characters long.',
      'Korisničko ime može imati najviše 256 znakova.': 'The username can be at most 256 characters long.',
      'Email može imati najviše 256 znakova.': 'The email can be at most 256 characters long.',
      'Ime može imati najviše 100 znakova.': 'The first name can be at most 100 characters long.',
      'Prezime može imati najviše 100 znakova.': 'The last name can be at most 100 characters long.',
      'Unesite ispravan broj telefona (6-20 cifara, dozvoljeni +, razmak, -).':
          'Enter a valid phone number (6-20 digits; +, space and - are allowed).',
      'Komentar može imati najviše 1000 znakova.': 'The comment can be at most 1000 characters long.',
      'Rezervacija je otkazana pa se na njoj može izvršiti samo povrat sredstava.':
          'The reservation is cancelled, so only a refund can be made on it.',
      'Termin je završen — online plaćanje više nije moguće, uplata se evidentira na terenu.':
          'The slot is over — online payment is no longer possible; the payment is recorded at the court.',
      'Ova radnja nije dozvoljena za trenutno stanje rezervacije i plaćanja.':
          'This action is not allowed for the current state of the reservation and payment.',
      'Rezervacija je već ocijenjena.': 'The reservation has already been rated.',
      'Recenzija je moguća samo za završenu rezervaciju.':
          'A review is only possible for a completed reservation.',
      'Rezervacija nema pokrenuto online plaćanje.':
          'No online payment has been started for this reservation.',
      'Registracija nije uspjela.': 'Registration failed.',
      'Lozinka je obavezna.': 'Password is required.',
      'Ime je obavezno.': 'First name is required.',
      'Prezime je obavezno.': 'Last name is required.',
      'Trenutna lozinka je obavezna.': 'The current password is required.',
      'Ime i prezime su obavezni.': 'Full name is required.',
      'Broj telefona je obavezan.': 'Phone number is required.',
    };
    for (final entry in messages.entries) {
      expect(await _englishMessageFor(tester, entry.key), entry.value);
    }
  });

  testWidgets('several messages in one response are translated line by line', (tester) async {
    expect(
      await _englishMessageFor(tester,
          'Korisničko ime mora imati najmanje 3 znaka.\nEmail može imati najviše 256 znakova.'),
      'The username must be at least 3 characters long.\nThe email can be at most 256 characters long.',
    );
    expect(
      await _englishMessageFor(tester, 'Neprevedeni tekst\nRezervacija je već ocijenjena.'),
      'Neprevedeni tekst\nThe reservation has already been rated.',
    );
  });

  testWidgets('refused reservation status change is translated with its statuses', (tester) async {
    expect(
      await _englishMessageFor(
          tester, "Nije moguća promjena statusa rezervacije sa 'Cancelled' na 'Cancelled'."),
      "The reservation status cannot be changed from 'Cancelled' to 'Cancelled'.",
    );
    expect(
      await _englishMessageFor(
          tester, "Nije moguća promjena statusa rezervacije sa 'Završeno' na 'Otkazano'."),
      "The reservation status cannot be changed from 'Completed' to 'Cancelled'.",
    );
    expect(
      await _englishMessageFor(
          tester, "Nije moguća promjena statusa rezervacije sa 'Na čekanju' na 'Potvrđena'."),
      "The reservation status cannot be changed from 'Pending' to 'Confirmed'.",
    );
  });

  testWidgets('unknown text is left untouched rather than breaking', (tester) async {
    expect(await _englishFor(tester, 'Neprevedeni tekst'), 'Neprevedeni tekst');
  });
}
