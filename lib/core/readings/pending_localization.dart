import 'dart:convert' show json, latin1, utf8;

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
      final merged = _sanitize(baseMap);
      try {
        final overlay =
            await rootBundle.loadString('assets/i18n/premium_$code.json');
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
      if (v is String) {
        out[k] = _fixUtf(v);
      } else if (v is Map) {
        out[k] = _sanitize(Map<String, dynamic>.from(v));
      } else if (v is List) {
        out[k] = v.map((e) => e is String ? _fixUtf(e) : e).toList();
      } else {
        out[k] = v;
      }
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
      if (RegExp(r'[ÃƒÃ„Ã…Ã‚]').hasMatch(out)) {
        final reparsed = utf8.decode(latin1.encode(out));
        if (reparsed.isNotEmpty) out = reparsed;
      }
    } catch (_) {}
    const fixes = {
      'Ã„Â±': 'ı',
      'Ã„Â°': 'İ',
      'ÃƒÂ¼': 'ü',
      'ÃƒÅ“': 'Ü',
      'ÃƒÂ¶': 'ö',
      'Ãƒâ€“': 'Ö',
      'ÃƒÂ§': 'ç',
      'Ãƒâ€¡': 'Ç',
      'Ã…Å¸': 'ş',
      'Ã…Å¾': 'Ş',
      'Ã„Å¸': 'ğ',
      'Ã„Å¾': 'Ğ',
      'Ã¢â‚¬â„¢': '’',
      'Ã¢â‚¬Å“': '“',
      'Ã¢â‚¬ï¿½': '”',
      'Ã¢â‚¬â€œ': '–',
      'Ã¢â‚¬â€': '—',
      'Ã‚': '',
    };
    fixes.forEach((k, v) {
      out = out.replaceAll(k, v);
    });
    out = out.replaceAll(RegExp('[\uFFFD]+'), '');
    out = out.replaceAll(RegExp('[\u0007]'), '');
    return out;
  }

  static String titleForType(String type, String locale) {
    switch (type) {
      case 'coffee':
        return _t('pending.title.coffee',
            locale.startsWith('tr') ? 'Kahve Yorumu' : 'Coffee Reading');
      case 'tarot':
        return _t('pending.title.tarot', 'Tarot');
      case 'palm':
        return _t('pending.title.palm',
            locale.startsWith('tr') ? 'El Çizgisi Yorumu' : 'Palm Reading');
      case 'astro':
        return _t('pending.title.astro',
            locale.startsWith('tr') ? 'Astroloji' : 'Astrology');
      case 'dream':
        return _t('pending.title.dream',
            locale.startsWith('tr') ? 'Rüya Tabiri' : 'Dream Interpretation');
      case 'motivation':
        return _t('pending.title.motivation',
            locale.startsWith('tr') ? 'Günlük Motivasyon' : 'Daily Motivation');
      default:
        return _t('pending.title.default',
            locale.startsWith('tr') ? 'Yorum' : 'Reading');
    }
  }

  static String bodyForType(String type, String locale) {
    switch (type) {
      case 'coffee':
        return _t(
            'pending.body.coffee',
            locale.startsWith('tr')
                ? 'Kahve yorumun hazır.'
                : 'Your coffee reading is ready');
      case 'tarot':
        return _t(
            'pending.body.tarot',
            locale.startsWith('tr')
                ? 'Tarot yorumun hazır.'
                : 'Your tarot reading is ready');
      case 'palm':
        return _t(
            'pending.body.palm',
            locale.startsWith('tr')
                ? 'El çizgisi yorumun hazır.'
                : 'Your palm reading is ready');
      case 'dream':
        return _t(
            'pending.body.dream',
            locale.startsWith('tr')
                ? 'Rüya tabirin hazır.'
                : 'Your dream interpretation is ready');
      case 'astro':
        return _t(
            'pending.body.astro',
            locale.startsWith('tr')
                ? 'Günlük astro yorumun hazır.'
                : 'Your daily astrology is ready');
      case 'motivation':
        return _t(
            'pending.body.motivation',
            locale.startsWith('tr')
                ? 'Günlük motivasyonun hazır.'
                : 'Your daily motivation is ready');
      default:
        return _t(
            'pending.body.default',
            locale.startsWith('tr')
                ? 'Yorumun hazır.'
                : 'Your reading is ready');
    }
  }
}
