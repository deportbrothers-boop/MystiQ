import 'dart:convert';
import 'dart:convert' show latin1, utf8;
import 'package:flutter/services.dart' show rootBundle;

class PendingI18n {
  static Map<String, dynamic>? _map;
  static String _code = 'en';

  static Future<void> ensure(String locale) async {
    final code = (locale.isNotEmpty ? locale.substring(0, 2) : 'en');
    if (_map != null && _code == code) return;
    _code = code;
    try {
      final base = await rootBundle.loadString('assets/i18n/$code.json');
      final baseMap = json.decode(base) as Map<String, dynamic>;
      Map<String, dynamic> merged = _sanitize(baseMap);
      // Merge premium overlay if exists (reuses overlay mechanism)
      try {
        final overlay = await rootBundle.loadString('assets/i18n/premium_$code.json');
        final extra = json.decode(overlay) as Map<String, dynamic>;
        merged.addAll(_sanitize(extra));
      } catch (_) {}
      _map = merged;
    } catch (_) {
      _map = {};
      _code = 'en';
    }
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> src) {
    final out = <String, dynamic>{};
    src.forEach((k, v) {
      if (v is String) out[k] = _fixUtf(v);
      else if (v is Map) out[k] = _sanitize(Map<String, dynamic>.from(v));
      else if (v is List) out[k] = v.map((e) => e is String ? _fixUtf(e) : e).toList();
      else out[k] = v;
    });
    return out;
  }

  static String _t(String key, String fallback) {
    final m = _map;
    if (m != null) {
      final v = m[key];
      if (v is String && v.isNotEmpty) return _fixUtf(v);
    }
    return _fixUtf(fallback);
  }

  static String _fixUtf(String s) {
    var out = s;
    try {
      if (RegExp(r'[ÃÄÅÂ]').hasMatch(out)) {
        final reparsed = utf8.decode(latin1.encode(out));
        if (reparsed.isNotEmpty) out = reparsed;
      }
    } catch (_) {}
    const fixes = {
      'Ä±': 'ı', 'Ä°': 'İ', 'Ã¼': 'ü', 'Ãœ': 'Ü', 'Ã¶': 'ö', 'Ã–': 'Ö',
      'Ã§': 'ç', 'Ã‡': 'Ç', 'ÅŸ': 'ş', 'Åž': 'Ş', 'ÄŸ': 'ğ', 'Äž': 'Ğ',
      'â€™': '’', 'â€œ': '“', 'â€�': '”', 'â€“': '–', 'â€”': '—', 'Â': ''
    };
    fixes.forEach((k, v) { out = out.replaceAll(k, v); });
    out = out.replaceAll(RegExp('[\uFFFD]+'), '');
    out = out.replaceAll(RegExp('[\u0007]'), '');
    return out;
  }

  static String titleForType(String t, String locale) {
    switch (t) {
      case 'coffee':
        return _t('pending.title.coffee', locale.startsWith('tr') ? 'Kahve Falı' : 'Coffee Reading');
      case 'tarot':
        return _t('pending.title.tarot', 'Tarot');
      case 'palm':
        return _t('pending.title.palm', locale.startsWith('tr') ? 'El Falı' : 'Palm Reading');
      case 'astro':
        return _t('pending.title.astro', locale.startsWith('tr') ? 'Astroloji' : 'Astrology');
      case 'dream':
        return _t('pending.title.dream', locale.startsWith('tr') ? 'Rüya Tabiri' : 'Dream Interpretation');
      default:
        return _t('pending.title.default', locale.startsWith('tr') ? 'Fal' : 'Reading');
    }
  }

  static String bodyForType(String t, String locale) {
    switch (t) {
      case 'coffee':
        return _t('pending.body.coffee', locale.startsWith('tr') ? 'Kahve falınız hazır' : 'Your coffee reading is ready');
      case 'tarot':
        return _t('pending.body.tarot', locale.startsWith('tr') ? 'Tarot yorumunuz hazır' : 'Your tarot reading is ready');
      case 'palm':
        return _t('pending.body.palm', locale.startsWith('tr') ? 'El falınız hazır' : 'Your palm reading is ready');
      case 'dream':
        return _t('pending.body.dream', locale.startsWith('tr') ? 'Rüya tabiriniz hazır' : 'Your dream interpretation is ready');
      case 'astro':
        return _t('pending.body.astro', locale.startsWith('tr') ? 'Günlük astro yorumunuz hazır' : 'Your daily astrology is ready');
      default:
        return _t('pending.body.default', locale.startsWith('tr') ? 'Falınız hazır' : 'Your reading is ready');
    }
  }
}

