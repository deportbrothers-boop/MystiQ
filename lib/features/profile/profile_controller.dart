import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_profile.dart';

class ProfileController with ChangeNotifier {
  static const _kKey = 'user_profile_v1';
  static const _kChatTone = 'chat.tone';
  static const _kChatLength = 'chat.length';

  UserProfile _profile = UserProfile.empty();
  UserProfile get profile => _profile;

  String chatTone = 'friendly'; // friendly|spiritual|humorous
  String chatLength = 'medium'; // short|medium|long

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_kKey);
    if (s != null) {
      _profile = UserProfile.fromJson(json.decode(s));
      // Migrate any mojibake zodiac names to clean Turkish once
      final fixedZodiac = _normalizeZodiac(_profile.zodiac);
      if (fixedZodiac != _profile.zodiac) {
        _profile = _profile.copyWith(zodiac: fixedZodiac);
        // persist silently
        await sp.setString(_kKey, json.encode(_profile.toJson()));
      }
    }
    chatTone = sp.getString(_kChatTone) ?? chatTone;
    chatLength = sp.getString(_kChatLength) ?? chatLength;
    notifyListeners();
  }

  // Normalize Turkish diacritics and known mojibake variants for zodiac names
  String _normalizeZodiac(String z) {
    String s = z;
    const map = {
      'Ko��': 'Koç', 'Koc': 'Koç', 'koc': 'Koç',
      'Bo�Ya': 'Boğa', 'Boga': 'Boğa',
      '��kizler': 'İkizler', 'Ikizler': 'İkizler',
      'Yenge��': 'Yengeç', 'Yengec': 'Yengeç',
      'Ba�Yak': 'Başak', 'Basak': 'Başak',
      'O�Ylak': 'Oğlak', 'Oglak': 'Oğlak',
      'Bal��k': 'Balık', 'Balik': 'Balık',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    // Generic diacritic fix-ups
    const more = {
      'Ã¼': 'ü', 'Ãœ': 'Ü', 'Ã¶': 'ö', 'Ã–': 'Ö', 'Ä±': 'ı', 'Ä°': 'İ', 'ÅŸ': 'ş', 'Åž': 'Ş',
      'Ã§': 'ç', 'Ã‡': 'Ç', 'ÄŸ': 'ğ', 'Äž': 'Ğ', 'Â': ''
    };
    more.forEach((k, v) => s = s.replaceAll(k, v));
    return s;
  }

  Future<void> save(UserProfile p) async {
    // Ensure zodiac is normalized before persisting
    _profile = p.copyWith(zodiac: _normalizeZodiac(p.zodiac));
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, json.encode(_profile.toJson()));
    notifyListeners();
  }

  Future<void> setChatPrefs({String? tone, String? length}) async {
    final sp = await SharedPreferences.getInstance();
    if (tone != null) {
      chatTone = tone;
      await sp.setString(_kChatTone, chatTone);
    }
    if (length != null) {
      chatLength = length;
      await sp.setString(_kChatLength, chatLength);
    }
    notifyListeners();
  }
}
