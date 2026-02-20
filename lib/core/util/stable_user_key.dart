import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StableUserKey {
  static const _kDeviceKey = 'stable_device_key_v1';

  /// Returns a stable per-user key.
  /// - If signed in: Firebase `uid`
  /// - Else: a locally stored random key
  static Future<String> get() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.trim().isNotEmpty) return uid.trim();
    } catch (_) {}

    final sp = await SharedPreferences.getInstance();
    final existing = sp.getString(_kDeviceKey);
    if (existing != null && existing.trim().isNotEmpty) return existing.trim();

    final created = _randomKey();
    try {
      await sp.setString(_kDeviceKey, created);
    } catch (_) {}
    return created;
  }

  static String _randomKey() {
    final rnd = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buf.write(chars[rnd.nextInt(chars.length)]);
    }
    return buf.toString();
  }
}

