import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController with ChangeNotifier {
  static const _kKey = 'localeCode';
  // İlk frame'de cihaz diline düşmemek için varsayılan TR.
  Locale? _locale = const Locale('tr');
  Locale? get locale => _locale;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_kKey);
    // Bu projede uygulama dili sabit TR (ilk açılışta İngilizceye düşmesin).
    _locale = const Locale('tr');
    if (code != 'tr') {
      try { await sp.setString(_kKey, 'tr'); } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    // Uygulama dili sabit TR
    _locale = const Locale('tr');
    final sp = await SharedPreferences.getInstance();
    try { await sp.setString(_kKey, 'tr'); } catch (_) {}
    notifyListeners();
  }
}
