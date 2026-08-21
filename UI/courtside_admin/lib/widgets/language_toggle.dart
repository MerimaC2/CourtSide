import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_locale.dart';

/// Small AppBar button that toggles between Bosnian and English. Shows the
/// language you'd switch *to*, not the current one — a common toggle-button
/// convention.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final targetLabel = locale.language == AppLanguage.bs ? 'EN' : 'BS';
    return TextButton.icon(
      onPressed: locale.toggle,
      icon: const Icon(Icons.language, color: Colors.white, size: 18),
      label: Text(targetLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}
