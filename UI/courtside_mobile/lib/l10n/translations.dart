import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_locale.dart';

/// Bosnian -> English lookup for every fixed UI string and runtime message
/// (success/error snackbars, including backend error text). Bosnian is the
/// app's original language, so it's always the dictionary key; when
/// [AppLanguage.bs] is active, [tr]/[trMessage] just return the input
/// unchanged. A string with no entry silently stays in Bosnian instead of
/// breaking — safer than throwing on a missed translation.
const Map<String, String> _dict = {
  // Login / register
  'Rezerviši svoj teren': 'Book your court',
  'Prijava': 'Login',
  'Korisničko ime': 'Username',
  'Unesite korisničko ime': 'Enter your username',
  'Lozinka': 'Password',
  'Unesite lozinku': 'Enter your password',
  'Nemate nalog? Registruj se': "Don't have an account? Sign up",
  'Registracija': 'Register',
  'Ime': 'First name',
  'Unesite ime': 'Enter your first name',
  'Prezime': 'Last name',
  'Unesite prezime': 'Enter your last name',
  'Unesite ispravan email': 'Enter a valid email',
  'Broj telefona': 'Phone number',
  'Lozinka mora imati bar 6 znakova': 'Password must be at least 6 characters',
  'Registruj se': 'Sign up',

  // Courts list
  'Tereni': 'Courts',
  'Moje rezervacije': 'My reservations',
  'Odjava': 'Logout',
  'Preporučeno za tebe': 'Recommended for you',
  'Pretraga terena...': 'Search courts...',
  'Svi sportovi': 'All sports',
  'Svi gradovi': 'All cities',
  'Grad': 'City',
  'Pokušaj ponovo': 'Try again',
  'Nema terena za zadane filtere.': 'No courts match the filters.',

  // Court details
  'Cijena po satu': 'Price per hour',
  'Lokacija': 'Location',
  'Aktivan': 'Active',
  'Neaktivan': 'Inactive',
  'Opis': 'Description',
  'Provjeri dostupnost': 'Check availability',

  // Availability
  'Dostupnost —': 'Availability —',
  'Nema definisanih termina za odabrani datum.': 'No slots defined for the selected date.',
  'Slobodno': 'Available',
  'Zauzeto': 'Booked',
  'Blokirano': 'Blocked',

  // Booking form
  'Forma za rezervaciju': 'Booking form',
  'Podaci za rezervaciju': 'Booking details',
  'Ime i prezime': 'Full name',
  'Unesite ime i prezime': 'Enter your full name',
  'Unesite broj telefona': 'Enter your phone number',
  'Napomena (opciono)': 'Note (optional)',
  'Način plaćanja': 'Payment method',
  'Gotovina pri dolasku': 'Cash on arrival',
  'Online plaćanje karticom': 'Online card payment',
  'Rezerviši': 'Book',
  'Teren': 'Court',
  'Datum': 'Date',
  'Termin': 'Time slot',
  'Ukupno': 'Total',
  'Plaćanje nije završeno': 'Payment was not completed',
  'Rezervacija je kreirana kao neplaćena.': 'The reservation was created as unpaid.',

  // Booking confirmation
  'Potvrda rezervacije': 'Reservation confirmation',
  'Rezervacija je uspješno kreirana!': 'Reservation created successfully!',
  'Iznos': 'Amount',
  'Plaćanje': 'Payment',
  'Plaćeno online': 'Paid online',
  'Plaćanje pri dolasku (gotovina)': 'Payment on arrival (cash)',
  'Nazad na terene': 'Back to courts',

  // My reservations
  'Otkazivanje rezervacije': 'Cancel reservation',
  'Razlog otkazivanja': 'Cancellation reason',
  'Nazad': 'Back',
  'Otkaži rezervaciju': 'Cancel reservation',
  'Rezervacija je otkazana.': 'Reservation cancelled.',
  'Aktivne': 'Active',
  'Historija': 'History',
  'Nema rezervacija.': 'No reservations.',
  'Otkaži': 'Cancel',
  'Otkazivanje nije moguće manje od 24h prije termina.':
      'Cancellation is not possible less than 24h before the slot.',

  // Reservation statuses (API always returns these in English)
  'Na čekanju': 'Pending',
  'Potvrđena': 'Confirmed',
  'Otkazana': 'Cancelled',
  'Završena': 'Completed',

  // Backend errors (from CourtSide.Services BusinessException/NotFoundException messages)
  'Pogrešno korisničko ime ili lozinka.': 'Incorrect username or password.',
  'Korisničko ime je već zauzeto.': 'This username is already taken.',
  'Email adresa je već registrovana.': 'This email address is already registered.',
  'Niste prijavljeni.': 'You are not logged in.',
  'Nemate pristup ovoj rezervaciji.': 'You do not have access to this reservation.',
  'Nemate pravo otkazati ovu rezervaciju.': 'You are not allowed to cancel this reservation.',
  'Razlog otkazivanja je obavezan.': 'A cancellation reason is required.',
  'Rezervaciju je moguće otkazati najkasnije 24 sata prije termina.':
      'A reservation can only be cancelled at least 24 hours before the slot.',
  'Termin rezervacije mora biti u budućnosti.': 'The reservation slot must be in the future.',
  'Vrijeme završetka mora biti nakon vremena početka.': 'The end time must be after the start time.',
  'Odabrani termin je već rezervisan.': 'The selected slot is already reserved.',
  'Odabrani termin je blokiran i nije dostupan.': 'The selected slot is blocked and unavailable.',
  'Odabrani termin je izvan radnog vremena terena.': "The selected slot is outside the court's working hours.",
  'Teren trenutno nije dostupan za rezervaciju.': 'The court is not currently available for booking.',
  'Rezervacija je već plaćena.': 'The reservation is already paid.',
  'Rezervacija nema evidentirano plaćanje.': 'The reservation has no recorded payment.',
  'Plaćanje je već refundirano.': 'The payment has already been refunded.',
  'Online plaćanje nije dostupno (Stripe nije konfigurisan).': 'Online payment is unavailable (Stripe is not configured).',
  'Nevalidan Stripe potpis.': 'Invalid Stripe signature.',
  'Došlo je do greške na serveru. Pokušajte ponovo kasnije.': 'A server error occurred. Please try again later.',

  // Client-side messages (thrown directly by BaseProvider, not the backend)
  'Sesija je istekla. Prijavite se ponovo.': 'Your session has expired. Please log in again.',
  'Nemate ovlaštenje za ovu radnju.': 'You are not authorized to perform this action.',
  'Greška pri dohvatu podataka.': 'Error fetching data.',
  'Nije pronađeno.': 'Not found.',
};

/// Entity names as they appear in NotFoundException("{entity} sa identifikatorom '{id}' nije pronađen.").
const Map<String, String> _entityNames = {
  'Rezervacija': 'Reservation',
  'Teren': 'Court',
  'Blokada': 'Block',
  'Notifikacija': 'Notification',
};

const Map<String, String> _stripePrefixes = {
  'Stripe greška pri povratu: ': 'Stripe error during refund: ',
  'Stripe greška: ': 'Stripe error: ',
};

final RegExp _notFoundPattern = RegExp(r"^(.+) sa identifikatorom '(.+)' nije pronađen\.$");

String _translate(String text, AppLanguage lang) {
  if (lang == AppLanguage.bs) return text;
  final exact = _dict[text];
  if (exact != null) return exact;
  final notFoundMatch = _notFoundPattern.firstMatch(text);
  if (notFoundMatch != null) {
    final entity = _entityNames[notFoundMatch.group(1)] ?? notFoundMatch.group(1)!;
    return "$entity with identifier '${notFoundMatch.group(2)}' not found.";
  }
  for (final entry in _stripePrefixes.entries) {
    if (text.startsWith(entry.key)) {
      return entry.value + text.substring(entry.key.length);
    }
  }
  return text;
}

/// For static UI text inside build() methods — rebuilds automatically when
/// the language changes.
String tr(BuildContext context, String bosnianText) =>
    _translate(bosnianText, context.watch<LocaleProvider>().language);

/// For one-off runtime messages (snackbars, dynamic text built outside
/// build(), dialog builders) — reads the current language without
/// subscribing to rebuilds.
String trMessage(BuildContext context, String bosnianText) =>
    _translate(bosnianText, context.read<LocaleProvider>().language);
