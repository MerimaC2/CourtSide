import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF1B7A43); // CourtSide green

String formatPrice(num? value) =>
    value == null ? '' : '${value.toStringAsFixed(2)} KM';

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
