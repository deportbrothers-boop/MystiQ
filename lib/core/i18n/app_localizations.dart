import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class AppLocalizations {
  final Locale locale;
  late final Map<String, dynamic> _map;
  Map<String, dynamic> _fallbackEn = const {};
  AppLocalizations(this.locale);

  Future<void> load() async {
    final code = locale.languageCode;
    if (code == 'tr') {
      final m = <String, dynamic>{};
      for (final p in [
        'assets/i18n/premium_tr.json',
        'assets/i18n/live_extra_tr.json',
        'assets/i18n/deep_tr.json',
        'assets/i18n/motivation_tr.json',
        'assets/i18n/tr_tone.json',
        'assets/i18n/extras_tr.json',
      ]) {
        try { m.addAll(json.decode(await rootBundle.loadString(p)) as Map<String, dynamic>); } catch (_) {}
      }
      try {
        final trBase = await rootBundle.loadString('assets/i18n/tr.json');
        final trMap = json.decode(trBase) as Map<String, dynamic>;
        for (final e in trMap.entries) { m.putIfAbsent(e.key, () => e.value); }
      } catch (_) {}
      _map = _sanitizeAll(m); // avoid EN merge for TR to prevent language mixing
    } else {
      try {
        final data = await rootBundle.loadString('assets/i18n/$code.json');
        _map = _sanitizeAll(json.decode(data) as Map<String, dynamic>);
      } catch (_) {
        final data = await rootBundle.loadString('assets/i18n/en.json');
        _map = _sanitizeAll(json.decode(data) as Map<String, dynamic>);
      }
      try {
        final enBase = await rootBundle.loadString('assets/i18n/en.json');
        _fallbackEn = json.decode(enBase) as Map<String, dynamic>;
      } catch (_) {}
      try {
        final overlay = await rootBundle.loadString('assets/i18n/premium_$code.json');
        _map.addAll(_sanitizeAll(json.decode(overlay) as Map<String, dynamic>));
      } catch (_) {}
      try {
        final motivation = await rootBundle.loadString('assets/i18n/motivation_$code.json');
        _map.addAll(_sanitizeAll(json.decode(motivation) as Map<String, dynamic>));
      } catch (_) {}
      try {
        final tone = await rootBundle.loadString('assets/i18n/${code}_tone.json');
        _map.addAll(_sanitizeAll(json.decode(tone) as Map<String, dynamic>));
      } catch (_) {}
      try {
        final extras = await rootBundle.loadString('assets/i18n/extras_${code}.json');
        _map.addAll(_sanitizeAll(json.decode(extras) as Map<String, dynamic>));
      } catch (_) {}
    }
  }

  String t(String key) {
    final raw = _map[key] as String? ?? key;
    final fixed = _normalizeUtf(raw);
    // Avoid EN fallback for Turkish; fix locally instead
    if (locale.languageCode != 'tr' && _looksBroken(fixed)) {
      final en = _fallbackEn[key];
      if (en is String && en.isNotEmpty) return en;
    }
    return fixed;
  }

  bool _looksBroken(String s) => RegExp(r'[\uFFFD\u0007]').hasMatch(s);

  String _normalizeUtf(String s) {
    if (s.isEmpty) return s;
    var out = s.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
    // Try to repair typical mojibake (UTF-8 shown as Latin-1)
    try {
      if (RegExp(r'[ÃÄÅÂ]').hasMatch(out)) {
        final reparsed = utf8.decode(latin1.encode(out));
        if (reparsed.isNotEmpty) out = reparsed;
      }
    } catch (_) {}
    // Map common sequences
    const fixes = {
      'Ä±': 'ı', 'Ä°': 'İ', 'Ã¼': 'ü', 'Ãœ': 'Ü', 'Ã¶': 'ö', 'Ã–': 'Ö',
      'Ã§': 'ç', 'Ã‡': 'Ç', 'ÅŸ': 'ş', 'Åž': 'Ş', 'ÄŸ': 'ğ', 'Äž': 'Ğ',
      'â€™': '’', 'â€˜': '‘', 'â€œ': '“', 'â€�': '”', 'â€“': '–', 'â€”': '—', 'â€¢': '•', 'â€¦': '…', 'Â': ''
    };
    fixes.forEach((k, v) { out = out.replaceAll(k, v); });
    // Strip replacement/control leftovers
    out = out.replaceAll(RegExp('[\uFFFD]+'), '');
    out = out.replaceAll(RegExp('[\u0007]'), '');
    return out;
  }

Map<String, dynamic> _sanitizeAll(Map<String, dynamic> src) {
  final out = <String, dynamic>{};
  for (final e in src.entries) {
    final v = e.value;
    if (v is String) {
      out[e.key] = _normalizeUtf(v);
    } else if (v is Map) {
      out[e.key] = _sanitizeAll(Map<String, dynamic>.from(v));
    } else if (v is List) {
      out[e.key] = v.map((x) => x is String ? _normalizeUtf(x) : x).toList();
    } else {
      out[e.key] = v;
    }
  }
  return out;
}

static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocDelegate();
}

class _AppLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocDelegate();
  @override
  bool isSupported(Locale locale) => ['tr', 'en', 'es', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final loc = AppLocalizations(locale);
    await loc.load();
    return loc;
  }

  @override
  bool shouldReload(_AppLocDelegate old) => false;
}






