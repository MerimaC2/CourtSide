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

/// Display label for a payment status (see [translateReservationStatus]).
String translatePaymentStatus(BuildContext context, String status) {
  if (context.watch<LocaleProvider>().language == AppLanguage.en) {
    return switch (status) {
      'Completed' => 'Paid',
      'RefundPending' => 'Refund pending',
      'RefundFailed' => 'Refund failed',
      _ => status,
    };
  }
  return switch (status) {
    'Pending' => 'Na čekanju',
    'Completed' => 'Plaćeno',
    'Refunded' => 'Refundirano',
    'Failed' => 'Neuspjelo',
    'RefundPending' => 'Povrat u toku',
    'RefundFailed' => 'Povrat neuspješan',
    _ => status,
  };
}

/// Display label for a payment method (see [translateReservationStatus]).
String translatePaymentMethod(BuildContext context, String method) {
  if (context.watch<LocaleProvider>().language == AppLanguage.en) return method;
  return switch (method) {
    'Cash' => 'Gotovina',
    'Stripe' => 'Kartica',
    _ => method,
  };
}

/// Shortens a reservation number like `RZ-20260811121848-FFD2` to just its
/// unique suffix (`FFD2`) for compact display; falls back to the full string
/// if it doesn't match the expected `RZ-<timestamp>-<suffix>` shape.
String shortReservationNumber(String reservationNumber) {
  final parts = reservationNumber.split('-');
  return parts.length == 3 ? parts.last : reservationNumber;
}

/// Shows a red error snackbar with [message] (translated if it matches a
/// known backend/client message and English is selected).
/// Errors stay until the user dismisses them. The default four seconds is meant for short
/// confirmations, which is not enough for a message that explains why an action was refused —
/// and unlike a confirmation, an error is the only record the user gets that nothing was saved.
void showError(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars(); // a new failure replaces the previous one instead of queueing
  messenger.showSnackBar(
    SnackBar(
      content: Text(trMessage(context, message)),
      backgroundColor: Colors.red,
      duration: const Duration(days: 1),
      action: SnackBarAction(
        label: trMessage(context, 'Zatvori poruku'),
        textColor: Colors.white,
        onPressed: messenger.hideCurrentSnackBar,
      ),
    ),
  );
}

/// Shows a green success snackbar with [message] (see [showError]).
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(trMessage(context, message)), backgroundColor: kPrimaryColor),
  );
}

/// Formats a UTC audit timestamp in the viewer's local time.
String formatDateTime(DateTime value) => DateFormat('dd.MM.yyyy. HH:mm').format(value.toLocal());
