import 'package:flutter/material.dart';

import '../l10n/translations.dart';

final _emailPattern = RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');
// Same shape the API enforces (digits, spaces and dashes, optional leading +), so a
// number the form accepts is never bounced by the server afterwards.
final _phonePattern = RegExp(r'^\+?[\d\s-]{6,20}$');
final _phoneDigits = RegExp(r'\d');
// The characters the server accepts in a username (ASP.NET Identity's default set).
final _usernamePattern = RegExp(r'^[A-Za-z0-9\-._@+]+$');

/// Email format check. The message spells out the expected shape rather than just
/// saying the value is wrong, so the user knows how to correct it.
String? validateEmail(BuildContext context, String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return trMessage(context, 'Unesite email adresu');
  if (!_emailPattern.hasMatch(email)) {
    return trMessage(context, 'Email mora biti u formatu: ime@domena.com');
  }
  return null;
}

/// Phone format check. Digits with optional spaces and dashes and an optional leading +,
/// with at least 6 digits.
/// Set [required] to false where a number is optional but must still be valid if given.
String? validatePhone(BuildContext context, String? value, {bool required = true}) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return required ? trMessage(context, 'Unesite broj telefona') : null;
  }
  if (!_phonePattern.hasMatch(phone)) {
    return trMessage(context, 'Unesite ispravan broj telefona (6-20 cifara, dozvoljeni +, razmak, -).');
  }
  if (_phoneDigits.allMatches(phone).length < 6) {
    return trMessage(context, 'Broj telefona mora imati najmanje 6 cifara, npr. 061 234 567');
  }
  return null;
}

/// Username check with the server's rules and wording, so a name the form accepts is not
/// refused on registration.
String? validateUsername(BuildContext context, String? value) {
  final username = value?.trim() ?? '';
  if (username.isEmpty) return trMessage(context, 'Korisničko ime je obavezno.');
  if (username.length < 3) {
    return trMessage(context, 'Korisničko ime mora imati najmanje 3 znaka.');
  }
  if (username.length > 256) {
    return trMessage(context, 'Korisničko ime može imati najviše 256 znakova.');
  }
  if (!_usernamePattern.hasMatch(username)) {
    return trMessage(context,
        'Korisničko ime smije sadržavati samo slova bez kvačica, brojeve i znakove - . _ @ +.');
  }
  return null;
}
