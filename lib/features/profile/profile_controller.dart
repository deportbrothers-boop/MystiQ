import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

    // Try to pull from Firestore for cross-device consistency
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final data = doc.data();
        if (data != null) {
          // Merge remote fields into local profile (remote wins if non-empty)
          final remote = UserProfile.fromJson(data);
          UserProfile merged = _profile;
          if (remote.name.isNotEmpty) merged = merged.copyWith(name: remote.name);
          if (remote.birthDate != null) merged = merged.copyWith(birthDate: remote.birthDate);
          if (remote.gender.isNotEmpty) merged = merged.copyWith(gender: remote.gender);
          if (remote.zodiac.isNotEmpty) merged = merged.copyWith(zodiac: _normalizeZodiac(remote.zodiac));
          if (remote.marital.isNotEmpty) merged = merged.copyWith(marital: remote.marital);
          // Merge remote photoUrl for cross-device avatar
          if ((remote.photoUrl ?? '').toString().isNotEmpty) {
            merged = merged.copyWith(photoUrl: remote.photoUrl);
          }
          _profile = merged;
          // persist locally
          await sp.setString(_kKey, json.encode(_profile.toJson()));
        }
      }
    } catch (_) {}
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
    var next = p.copyWith(zodiac: _normalizeZodiac(p.zodiac));
    // Attempt upload of local photo to Firebase Storage, set photoUrl
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final path = p.photoPath;
      if (uid != null && path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final ref = FirebaseStorage.instance.ref().child('users').child(uid).child('profile').child('avatar.jpg');
          await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
          final url = await ref.getDownloadURL();
          if (url.isNotEmpty) {
            next = next.copyWith(photoUrl: url);
          }
        }
      }
    } catch (_) {}
    // Preserve existing remote url if no new upload
    if ((next.photoUrl == null || next.photoUrl!.isEmpty) && (_profile.photoUrl != null && _profile.photoUrl!.isNotEmpty)) {
      next = next.copyWith(photoUrl: _profile.photoUrl);
    }
    _profile = next;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kKey, json.encode(_profile.toJson()));
    // Push to Firestore (best-effort)
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(_profile.toJson(), SetOptions(merge: true));
      }
    } catch (_) {}
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

  Future<void> clearLocal() async {
    _profile = UserProfile.empty();
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
    notifyListeners();
  }
}
