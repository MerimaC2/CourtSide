import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

/// Shows a red error snackbar with [message].
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}

/// Shows a green success snackbar with [message].
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: kPrimaryColor),
  );
}
