import 'package:flutter/material.dart';

import '../l10n/translations.dart';

final _emailPattern = RegExp(r'^[\w.!#$%&*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$');
final _phonePattern = RegExp(r'^\+?[\d\s()/-]{6,20}$');
final _phoneDigits = RegExp(r'\d');

/// Email format check. The message spells out the expected shape rather than just
/// saying the value is wrong, so the user knows how to correct it.
String? validateEmail(BuildContext context, String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return tr(context, 'Unesite email adresu');
  if (!_emailPattern.hasMatch(email)) {
    return tr(context, 'Email mora biti u formatu: ime@domena.com');
  }
  return null;
}

/// Phone format check. Digits with optional spaces, +, -, / and parentheses.
/// Set [required] to false where a number is optional but must still be valid if given.
String? validatePhone(BuildContext context, String? value, {bool required = true}) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return required ? tr(context, 'Unesite broj telefona') : null;
  }
  final digits = _phoneDigits.allMatches(phone).length;
  if (!_phonePattern.hasMatch(phone) || digits < 6) {
    return tr(context, 'Broj telefona mora imati najmanje 6 cifara, npr. 061 234 567');
  }
  return null;
}
