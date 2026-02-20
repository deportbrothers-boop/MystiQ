import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class AiGenerationGuardException implements Exception {
  final String reason;
  const AiGenerationGuardException(this.reason);

  @override
  String toString() => 'AiGenerationGuardException($reason)';
}

class AiGenerationGuard {
  static const _kPermits = 'ai_generation_permits_v1';
  static Future<void> _lock = Future.value();

  static Future<T> _withLock<T>(Future<T> Function() fn) {
    late final Future<T> next;
    next = _lock.then((_) => fn(), onError: (_) => fn());
    _lock = next.then((_) {}, onError: (_) {});
    return next;
  }

  static String _newPermit() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final r = Random.secure().nextInt(1 << 31);
    return '$now-$r';
  }

  static Future<String> issuePermit() async {
    final permit = _newPermit();
    return _withLock(() async {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_kPermits) ?? <String>[];
      list.add(permit);
      // Prevent unbounded growth in case permits are never consumed.
      const max = 500;
      if (list.length > max) {
        list.removeRange(0, list.length - max);
      }
      await sp.setStringList(_kPermits, list);
      return permit;
    });
  }

  static Future<bool> consumePermit(String? permit) async {
    final p = permit?.trim() ?? '';
    if (p.isEmpty) return false;
    return _withLock(() async {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_kPermits) ?? <String>[];
      final idx = list.indexOf(p);
      if (idx < 0) return false;
      list.removeAt(idx);
      await sp.setStringList(_kPermits, list);
      return true;
    });
  }
}

