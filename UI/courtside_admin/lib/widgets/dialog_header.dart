import 'package:flutter/material.dart';

import '../l10n/translations.dart';

/// Title row for a modal form, with the close control in the top-right corner that
/// users expect. [onClose] defaults to dismissing the dialog with no result.
Widget dialogHeader(BuildContext context, String title, {VoidCallback? onClose}) {
  return Row(
    children: [
      Expanded(child: Text(title)),
      IconButton(
        tooltip: tr(context, 'Zatvori'),
        icon: const Icon(Icons.close),
        onPressed: onClose ?? () => Navigator.of(context).pop(),
      ),
    ],
  );
}
