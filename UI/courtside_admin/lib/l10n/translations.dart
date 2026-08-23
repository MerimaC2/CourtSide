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
  // Shell / navigation
  'Tereni': 'Courts',
  'Raspored': 'Schedule',
  'Rezervacije': 'Reservations',
  'Izvještaji': 'Reports',
  'Referentni podaci': 'Reference data',
  'Odjava': 'Logout',

  // Login
  'Administratorska prijava': 'Administrator Login',
  'Prijava': 'Login',
  'Korisničko ime': 'Username',
  'Unesite korisničko ime': 'Enter your username',
  'Lozinka': 'Password',
  'Unesite lozinku': 'Enter your password',
  'Ovaj nalog nema administratorska prava.': 'This account does not have administrator privileges.',

  // Courts
  'Pretraga terena...': 'Search courts...',
  'Dodaj teren': 'Add court',
  'Pokušaj ponovo': 'Try again',
  'Nema terena.': 'No courts.',
  'Naziv': 'Name',
  'Sportski centar': 'Sports center',
  'Cijena/h': 'Price/h',
  'Akcije': 'Actions',
  'Uredi': 'Edit',
  'Obriši': 'Delete',
  'Aktivan': 'Active',
  'Neaktivan': 'Inactive',
  'Odaberi sliku': 'Choose photo',
  'Brisanje terena': 'Delete court',
  'Obrisati teren': 'Delete court',
  'Odustani': 'Cancel',
  'Teren je dodan.': 'Court added.',
  'Teren je ažuriran.': 'Court updated.',
  'Teren je obrisan.': 'Court deleted.',
  'Novi teren': 'New court',
  'Uređivanje terena': 'Edit court',
  'Unesite naziv': 'Enter a name',
  'Odaberite sport': 'Select a sport',
  'Odaberite sportski centar': 'Select a sports center',
  'Cijena po satu (KM)': 'Price per hour (KM)',
  'Unesite ispravnu cijenu': 'Enter a valid price',
  'Opis (opciono)': 'Description (optional)',
  'Sačuvaj': 'Save',
  'Radno vrijeme': 'Working hours',
  'Termini se generišu iz radnog vremena.': 'Time slots are generated from the working hours.',
  'Ponedjeljak': 'Monday',
  'Utorak': 'Tuesday',
  'Srijeda': 'Wednesday',
  'Četvrtak': 'Thursday',
  'Petak': 'Friday',
  'Subota': 'Saturday',
  'Nedjelja': 'Sunday',
  'Teren mora biti otvoren barem jedan dan, a zatvaranje mora biti nakon otvaranja.':
      'The court must be open at least one day, and closing must be after opening.',
  'Vrijeme zatvaranja mora biti nakon vremena otvaranja.':
      'Closing time must be after opening time.',

  // Schedule
  'Nema terena. Prvo dodajte teren.': 'No courts. Add a court first.',
  'Teren': 'Court',
  'Datum': 'Date',
  'Nema definisanih termina za odabrani datum.': 'No slots defined for the selected date.',
  'Slobodno (klik za blokiranje)': 'Available (click to block)',
  'Rezervisano': 'Reserved',
  'Blokirano (klik za odblokiranje)': 'Blocked (click to unblock)',
  'Termin je već rezervisan.': 'This slot is already reserved.',
  'Razlog (opciono)': 'Reason (optional)',
  'Blokiraj': 'Block',
  'Ukloniti blokadu ovog termina?': 'Remove the block on this slot?',
  'Odblokiraj': 'Unblock',
  'Termin je blokiran.': 'Slot blocked.',
  'Blokada je uklonjena.': 'Block removed.',
  'Blokiraj termin': 'Block slot',
  'Odblokiraj termin': 'Unblock slot',
  'Razlog blokade': 'Block reason',

  // Reservations
  'Pretraga (broj, klijent)...': 'Search (number, client)...',
  'Svi statusi': 'All statuses',
  'Od datuma': 'From date',
  'Do datuma': 'To date',
  'Očisti filtere': 'Clear filters',
  'Nema rezervacija za zadane filtere.': 'No reservations match the filters.',
  'Broj': 'Number',
  'Klijent': 'Client',
  'Termin': 'Time slot',
  'Iznos': 'Amount',
  'Plaćanje': 'Payment',
  'Detalji': 'Details',
  'Otkazivanje rezervacije': 'Cancel reservation',
  'Razlog otkazivanja': 'Cancellation reason',
  'Nazad': 'Back',
  'Otkaži rezervaciju': 'Cancel reservation',
  'Kontakt telefon': 'Contact phone',
  'Način plaćanja': 'Payment method',
  'Status plaćanja': 'Payment status',
  'Napomena': 'Note',
  'Zatvori': 'Close',
  'Označi kao plaćeno': 'Mark as paid',
  'Refundiraj': 'Refund',
  'Otkaži': 'Cancel',
  'Potvrdi': 'Confirm',
  'Nema podataka o plaćanju.': 'No payment information.',
  'Plaćeno': 'Paid',
  'Refundirano': 'Refunded',
  'Uplata gotovinom je evidentirana.': 'Cash payment recorded.',
  'Refund je pokrenut.': 'Refund initiated.',
  'Rezervacija je potvrđena.': 'Reservation confirmed.',
  'Rezervacija je otkazana.': 'Reservation cancelled.',

  // Reports
  'Izvještaj o rezervacijama': 'Reservations report',
  'Sažetak po statusu, ostvareni prihod i pregled rezervacija za odabrani period.':
      'Summary by status, revenue, and a list of reservations for the selected period.',
  'Svi centri': 'All centers',
  'Generiši i sačuvaj PDF': 'Generate and save PDF',
  'Izvještaj je sačuvan.': 'Report saved.',
  'Izvještaj je sačuvan u:': 'Report saved to:',
  'Otvori': 'Open',

  // News
  'Obavijesti': 'News',
  'Nova obavijest': 'New announcement',
  'Uređivanje obavijesti': 'Edit announcement',
  'Naslov': 'Title',
  'Unesite naslov': 'Enter a title',
  'Tekst': 'Text',
  'Unesite tekst': 'Enter the text',
  'Datum objave': 'Publish date',
  'Pretraga obavijesti...': 'Search announcements...',
  'Dodaj obavijest': 'Add announcement',
  'Nema obavijesti.': 'No announcements.',
  'Brisanje obavijesti': 'Delete announcement',
  'Obrisati obavijest': 'Delete announcement',
  'Obavijest je dodana.': 'Announcement added.',
  'Obavijest je ažurirana.': 'Announcement updated.',
  'Obavijest je obrisana.': 'Announcement deleted.',

  // Reference data (sports, sport centers, cities, countries)
  'Sportovi': 'Sports',
  'Sportski centri': 'Sports centers',
  'Gradovi': 'Cities',
  'Države': 'Countries',
  'Opis': 'Description',
  'Grad': 'City',
  'Država': 'Country',
  'Adresa': 'Address',
  'Unesite adresu': 'Enter an address',
  'Odaberite grad': 'Select a city',
  'Odaberite državu': 'Select a country',
  'ISO kod': 'ISO code',
  'ISO kod (opciono)': 'ISO code (optional)',
  'Poštanski broj': 'Postal code',
  'Poštanski broj (opciono)': 'Postal code (optional)',
  'Koordinate nisu postavljene': 'Coordinates not set',
  'Odaberi na karti': 'Pick on map',
  'Odaberi lokaciju na karti': 'Pick a location on the map',
  'Kliknite na kartu da postavite oznaku.': 'Click the map to place a marker.',
  'Lokacija nije odabrana': 'No location selected',
  'Adresa nije pronađena. Označite lokaciju na karti.':
      'Address not found. Mark the location on the map.',
  'Adresa ili grad': 'Address or city',
  'Pretraži': 'Search',
  'Pretraga koordinata nije uspjela. Pokušajte ponovo.':
      'Coordinate search failed. Please try again.',

  'Pretraga sportova...': 'Search sports...',
  'Dodaj sport': 'Add sport',
  'Nema sportova.': 'No sports.',
  'Novi sport': 'New sport',
  'Uređivanje sporta': 'Edit sport',
  'Brisanje sporta': 'Delete sport',
  'Obrisati sport': 'Delete sport',
  'Sport je dodan.': 'Sport added.',
  'Sport je ažuriran.': 'Sport updated.',
  'Sport je obrisan.': 'Sport deleted.',

  'Pretraga država...': 'Search countries...',
  'Dodaj državu': 'Add country',
  'Nema država.': 'No countries.',
  'Nova država': 'New country',
  'Uređivanje države': 'Edit country',
  'Brisanje države': 'Delete country',
  'Obrisati državu': 'Delete country',
  'Država je dodana.': 'Country added.',
  'Država je ažurirana.': 'Country updated.',
  'Država je obrisana.': 'Country deleted.',

  'Pretraga gradova...': 'Search cities...',
  'Dodaj grad': 'Add city',
  'Nema gradova.': 'No cities.',
  'Novi grad': 'New city',
  'Uređivanje grada': 'Edit city',
  'Brisanje grada': 'Delete city',
  'Obrisati grad': 'Delete city',
  'Grad je dodan.': 'City added.',
  'Grad je ažuriran.': 'City updated.',
  'Grad je obrisan.': 'City deleted.',

  'Pretraga sportskih centara...': 'Search sports centers...',
  'Dodaj sportski centar': 'Add sports center',
  'Nema sportskih centara.': 'No sports centers.',
  'Novi sportski centar': 'New sports center',
  'Uređivanje sportskog centra': 'Edit sports center',
  'Brisanje sportskog centra': 'Delete sports center',
  'Obrisati sportski centar': 'Delete sports center',
  'Sportski centar je dodan.': 'Sports center added.',
  'Sportski centar je ažuriran.': 'Sports center updated.',
  'Sportski centar je obrisan.': 'Sports center deleted.',

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
  'Stripe webhook nije konfigurisan (nedostaje STRIPE_WEBHOOK_SECRET).':
      'The Stripe webhook is not configured (STRIPE_WEBHOOK_SECRET is missing).',
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
