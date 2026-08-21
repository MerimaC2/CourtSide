import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/translations.dart';
import 'app_locale.dart';

const Color kPrimaryColor = Color(0xFF1B7A43); // CourtSide green

String formatPrice(num? value) =>
    value == null ? '' : '${value.toStringAsFixed(2)} KM';

/// Formats a [DateTime] as the `yyyy-MM-dd` string the API expects for `DateOnly` params/fields.
String formatApiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Formats a `yyyy-MM-dd` API date string for display (e.g. `10.08.2026.`).
String formatDisplayDate(String apiDate) {
  final parsed = DateTime.tryParse(apiDate);
  if (parsed == null) return apiDate;
  return DateFormat('dd.MM.yyyy.').format(parsed);
}

/// Display label for a reservation status. The API always returns these in
/// English (`Pending`, `Confirmed`, ...) — comparisons against the raw value
/// elsewhere in the app must keep using the English string; this is for
/// display only, and respects the currently selected UI language.
String translateReservationStatus(BuildContext context, String status) {
  if (context.watch<LocaleProvider>().language == AppLanguage.en) return status;
  return switch (status) {
    'Pending' => 'Na čekanju',
    'Confirmed' => 'Potvrđena',
    'Cancelled' => 'Otkazana',
    'Completed' => 'Završena',
    _ => status,
  };
}

/// Shows a red error snackbar with [message] (translated if it matches a
/// known backend/client message and English is selected).
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(trMessage(context, message)), backgroundColor: Colors.red),
  );
}

/// Shows a green success snackbar with [message] (see [showError]).
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(trMessage(context, message)), backgroundColor: kPrimaryColor),
  );
}
