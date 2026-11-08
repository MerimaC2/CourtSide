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

/// Date and time exactly as [value] reads, e.g. `28.09.2026. 09:00`. Nothing is converted
/// to the device's zone, so a venue wall-clock time (such as a reservation's cancel
/// deadline) is shown the same on every device.
String formatDisplayDateTime(DateTime value) => DateFormat('dd.MM.yyyy. HH:mm').format(value);

/// Payment statuses arrive as the API's English enum names; the labels are distinct from the
/// reservation ones ("Nije plaćeno" rather than "Na čekanju") so the two badges never read alike.
String translatePaymentStatus(BuildContext context, String status) {
  final bs = switch (status) {
    'Pending' => 'Nije plaćeno',
    'Completed' => 'Plaćeno',
    'Failed' => 'Plaćanje neuspjelo',
    'Refunded' => 'Refundirano',
    'RefundPending' => 'Povrat u toku',
    'RefundFailed' => 'Povrat neuspješan',
    _ => status,
  };
  return tr(context, bs);
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
/// Errors stay until the user dismisses them. The default four seconds is meant for short
/// confirmations, which is not enough for a message that explains why an action was refused —
/// and unlike a confirmation, an error is the only record the user gets that nothing was saved.
/// An error belongs to the screen it is shown on and is closed when the user moves to another
/// screen (see [ErrorSnackBarObserver]); to report a failure on the screen a flow leads to,
/// navigate first and show the error afterwards.
void showError(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars(); // a new failure replaces the previous one instead of queueing
  final open = (
    messenger,
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
    ),
  );
  _openError = open;
  open.$2.closed.then((_) {
    if (_openError == open) _openError = null;
  });
}

/// The error snackbar on screen and the messenger showing it, until it closes.
(ScaffoldMessengerState, ScaffoldFeatureController<SnackBar, SnackBarClosedReason>)? _openError;

/// Closes the open error snackbar when the user moves to another screen, where it would only
/// cover content (such as the next screen's buttons). Registered on the app's navigator.
class ErrorSnackBarObserver extends NavigatorObserver {
  Route<dynamic>? _screen;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    // Dialogs, sheets and menus open over the same screen, so they leave the message in place.
    if (topRoute is! PageRoute || topRoute == _screen) return;
    _screen = topRoute;
    final open = _openError;
    _openError = null;
    if (open != null && open.$1.mounted) open.$1.clearSnackBars();
  }
}

/// Shows a green success snackbar with [message] (see [showError]).
void showSuccess(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  // An open error is cleared first, so this confirmation is shown right away.
  if (_openError != null) messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(content: Text(trMessage(context, message)), backgroundColor: kPrimaryColor),
  );
}
