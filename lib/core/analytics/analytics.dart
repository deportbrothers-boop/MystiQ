import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Analytics {
  static const _kKey = 'analytics_events_v1';

  static Future<void> log(String name, [Map<String, dynamic>? params]) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kKey) ?? [];
    final event = {
      'name': name,
      'params': params ?? {},
      'ts': DateTime.now().toIso8601String(),
    };
    list.add(json.encode(event));
    await sp.setStringList(_kKey, list);
  }

  static Future<Map<String, int>> summary() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kKey) ?? [];
    final counts = <String, int>{};
    for (final s in list) {
      final j = json.decode(s) as Map<String, dynamic>;
      final n = j['name'] as String;
      counts[n] = (counts[n] ?? 0) + 1;
    }
    return counts;
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kKey);
  }
}

