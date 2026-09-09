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
  'Broj telefona': 'Phone number',
  'Lozinka mora imati bar 6 znakova': 'Password must be at least 6 characters',
  'Unesite email adresu': 'Enter an email address',
  'Email mora biti u formatu: ime@domena.com': 'Email must look like: name@domain.com',
  'Broj telefona mora imati najmanje 6 cifara, npr. 061 234 567':
      'Phone number needs at least 6 digits, e.g. 061 234 567',
  'Trenutna lozinka nije ispravna.': 'The current password is incorrect.',
  'Nova lozinka je prekratka.': 'The new password is too short.',
  'Registruj se': 'Sign up',

  // Image upload validation
  'Fajl je prazan.': 'The file is empty.',
  'Slika ne smije biti veća od 5 MB.': 'The image must not exceed 5 MB.',
  'Dozvoljeni formati slike su JPEG, PNG i WebP.': 'Allowed image formats are JPEG, PNG and WebP.',
  'Sadržaj fajla ne odgovara prijavljenom formatu slike.':
      'The file contents do not match the declared image format.',

  // Profile
  'Moj profil': 'My profile',
  'Profil je ažuriran.': 'Profile updated.',
  'Profilna slika je ažurirana.': 'Profile picture updated.',
  'Promjena lozinke': 'Change password',
  'Promijeni lozinku': 'Change password',
  'Trenutna lozinka': 'Current password',
  'Nova lozinka': 'New password',
  'Potvrda nove lozinke': 'Confirm new password',
  'Lozinke se ne podudaraju': 'Passwords do not match',
  'Lozinka je promijenjena.': 'Password changed.',
  'Sačuvaj': 'Save',
  'Odustani': 'Cancel',

  // News
  'Obavijesti': 'News',
  'Nema obavijesti.': 'No announcements.',

  // Notifications
  'Notifikacije': 'Notifications',
  'Rezervacija kreirana': 'Reservation created',
  'Rezervacija potvrđena': 'Reservation confirmed',
  'Rezervacija otkazana': 'Reservation cancelled',
  'Rezervacija završena': 'Reservation completed',
  'Plaćanje evidentirano': 'Payment recorded',
  'Plaćanje uspješno': 'Payment successful',
  'Povrat sredstava': 'Refund issued',
  'Nema notifikacija.': 'No notifications.',
  'Označi sve kao pročitano': 'Mark all as read',

  // Reviews
  'Recenzije': 'Reviews',
  'Još nema recenzija.': 'No reviews yet.',
  'Ocijeni teren': 'Rate the court',
  'Komentar (opciono)': 'Comment (optional)',
  'Ocijeni': 'Rate',
  'Hvala na ocjeni!': 'Thanks for the rating!',

  // Courts list
  'Tereni': 'Courts',
  'Moje rezervacije': 'My reservations',
  'Odjava': 'Logout',
  'Preporučeno za tebe': 'Recommended for you',
  // Explanations returned by the recommender (see recommender-dokumentacija.md).
  'Korisnici sa sličnim rezervacijama često biraju ovaj teren.':
      'Users with similar bookings often choose this court.',
  'Najpopularniji teren u zadnjih 30 dana.': 'Most popular court in the last 30 days.',
  'Predloženo za tebe.': 'Suggested for you.',
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
  'Plaćanje je u obradi': 'Payment is being processed',
  'Plaćanje nije uspjelo — rezervacija je neplaćena': 'Payment failed — the reservation is unpaid',
  'Konačan status plaćanja vidjet ćete u Mojim rezervacijama.': 'You will see the final payment status in My reservations.',
  'Plaćanje pri dolasku (gotovina)': 'Payment on arrival (cash)',
  'Nazad na terene': 'Back to courts',

  // My reservations
  'Otkazivanje rezervacije': 'Cancel reservation',
  'Razlog otkazivanja': 'Cancellation reason',
  'Nazad': 'Back',
  'Zatvori': 'Close',
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

  'Zatvori poruku': 'Dismiss',

  // Backend errors (from CourtSide.Services BusinessException/NotFoundException messages)
  'Odaberite termin iz ponuđenog rasporeda terena.': 'Choose a slot from the court schedule.',
  'Rezervacija nije potvrđena prije početka termina.': 'The reservation was not confirmed before the slot started.',
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
  'Podatke nije moguće sačuvati. Provjerite unos i povezane zapise.':
      'The data could not be saved. Check the entry and the records it refers to.',
  'Nova lozinka mora biti različita od trenutne.': 'The new password must differ from the current one.',

  // Client-side messages (thrown directly by BaseProvider, not the backend)
  'Sesija je istekla. Prijavite se ponovo.': 'Your session has expired. Please log in again.',
  'Nemate ovlaštenje za ovu radnju.': 'You are not authorized to perform this action.',
  'Greška pri dohvatu podataka.': 'Error fetching data.',
  'Nije pronađeno.': 'Not found.',
};

/// Entity names as they appear in NotFoundException("Ne postoji {entity} sa identifikatorom '{id}'."), lower-cased by the server.
const Map<String, String> _entityNames = {
  'rezervacija': 'reservation',
  'teren': 'court',
  'blokada': 'block',
  'notifikacija': 'notification',
  'recenzija': 'review',
  'obavijest': 'news item',
  'plaćanje': 'payment',
  'sportski centar': 'sport center',
};

const Map<String, String> _stripePrefixes = {
  'Stripe greška pri povratu: ': 'Stripe error during refund: ',
  'Stripe greška: ': 'Stripe error: ',
};

/// Notification bodies are generated by the API and embed the reservation's short
/// number (and, for cancellations, the reason the user typed). They can't be looked up
/// verbatim, so each one is matched by shape and rebuilt with the captured parts.
final List<({RegExp shape, String Function(List<String?>) build})> _notificationPatterns = [
  (
    shape: RegExp(r'^Vaša rezervacija (.+) je kreirana i čeka potvrdu\.$'),
    build: (g) => 'Your reservation ${g[0]} has been created and is awaiting confirmation.',
  ),
  (
    shape: RegExp(r'^Vaša rezervacija (.+) je potvrđena\.$'),
    build: (g) => 'Your reservation ${g[0]} has been confirmed.',
  ),
  (
    shape: RegExp(r'^Vaša rezervacija (.+) je završena\. Možete ocijeniti teren\.$'),
    build: (g) => 'Your reservation ${g[0]} is complete. You can now rate the court.',
  ),
  (
    shape: RegExp(r'^Rezervacija (.+) je otkazana\. Razlog: (.*)$'),
    build: (g) => 'Reservation ${g[0]} has been cancelled. Reason: ${g[1]}',
  ),
  (
    shape: RegExp(r'^Gotovinsko plaćanje za rezervaciju (.+) je evidentirano\.$'),
    build: (g) => 'Cash payment for reservation ${g[0]} has been recorded.',
  ),
  (
    shape: RegExp(r'^Online plaćanje za rezervaciju (.+) je zaprimljeno\.$'),
    build: (g) => 'Online payment for reservation ${g[0]} has been received.',
  ),
  (
    shape: RegExp(r'^Izvršen je povrat za rezervaciju (.+)\.$'),
    build: (g) => 'A refund has been issued for reservation ${g[0]}.',
  ),
];

final RegExp _notFoundPattern = RegExp(r"^Ne postoji (.+) sa identifikatorom '(.+)'\.$");

String _translate(String text, AppLanguage lang) {
  if (lang == AppLanguage.bs) return text;
  final exact = _dict[text];
  if (exact != null) return exact;
  final notFoundMatch = _notFoundPattern.firstMatch(text);
  if (notFoundMatch != null) {
    final entity = _entityNames[notFoundMatch.group(1)] ?? notFoundMatch.group(1)!;
    final named = entity.isEmpty ? entity : entity[0].toUpperCase() + entity.substring(1);
    return "$named with identifier '${notFoundMatch.group(2)}' not found.";
  }
  for (final pattern in _notificationPatterns) {
    final match = pattern.shape.firstMatch(text);
    if (match != null) {
      return pattern.build([for (var i = 1; i <= match.groupCount; i++) match.group(i)]);
    }
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
