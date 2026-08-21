import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { bs, en }

const _prefsKey = 'app_language';

/// Holds the currently selected UI language and persists it across launches.
/// Defaults to Bosnian (the app's original language) until a saved
/// preference is loaded or the user switches explicitly.
class LocaleProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.bs;

  AppLanguage get language => _language;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'en') {
      _language = AppLanguage.en;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _language = _language == AppLanguage.bs ? AppLanguage.en : AppLanguage.bs;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _language == AppLanguage.en ? 'en' : 'bs');
  }
}
