import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController with ChangeNotifier {
  static const _kKey = 'localeCode';
  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_kKey);
    if (code != null) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    final sp = await SharedPreferences.getInstance();
    if (locale == null) {
      await sp.remove(_kKey);
    } else {
      await sp.setString(_kKey, locale.languageCode);
    }
    notifyListeners();
  }
}

