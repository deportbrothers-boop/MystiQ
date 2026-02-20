import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final files = <String>[
    'assets/i18n/tr.json',
    'assets/i18n/premium_tr.json',
  ];

  for (final path in files) {
    final file = File(path);
    if (!await file.exists()) continue;
    final raw = await file.readAsString(encoding: utf8);
    final data = json.decode(raw);
    final fixed = _fixJson(data);
    final pretty = const JsonEncoder.withIndent('  ').convert(fixed);
    await file.writeAsString(pretty, encoding: utf8);
    stdout.writeln('Fixed: $path');
  }
}

dynamic _fixJson(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(_fixString(k.toString()), _fixJson(v)));
  }
  if (value is List) return value.map(_fixJson).toList();
  if (value is String) return _fixString(value);
  return value;
}

String _fixString(String s) {
  if (s.isEmpty) return s;

  var out = s;

  // Repair common UTF-8-as-Latin1 mojibake by round-tripping if it looks suspicious.
  if (RegExp(r'[ÃÄÅÂâ]').hasMatch(out)) {
    for (var i = 0; i < 3; i++) {
      try {
        final bytes = latin1.encode(out);
        final decoded = utf8.decode(bytes, allowMalformed: true);
        if (decoded == out) break;
        out = decoded;
      } catch (_) {
        break;
      }
    }
  }

  final repl = <String, String>{
    // Broken Turkish letters (most common)
    '\u00C4\u00B1': '\u0131', // Ä± -> ı
    '\u00C4\u00B0': '\u0130', // Ä° -> İ
    '\u00C3\u00BC': '\u00FC', // Ã¼ -> ü
    '\u00C3\u009C': '\u00DC', // Ãœ -> Ü
    '\u00C3\u00B6': '\u00F6', // Ã¶ -> ö
    '\u00C3\u0096': '\u00D6', // Ã– -> Ö
    '\u00C3\u00A7': '\u00E7', // Ã§ -> ç
    '\u00C3\u0087': '\u00C7', // Ã‡ -> Ç
    '\u00C5\u009F': '\u015F', // ÅŸ -> ş
    '\u00C5\u009E': '\u015E', // Åž -> Ş
    '\u00C4\u0178': '\u011F', // ÄŸ -> ğ
    '\u00C4\u009F': '\u011F', // variant
    '\u00C4\u017E': '\u011E', // Äž -> Ğ

    // Variants seen in some files (already-unicode, but wrong)
    'ÅŸ': 'ş',
    'Åž': 'Ş',
    'Ã¼': 'ü',
    'Ãœ': 'Ü',
    'Ã¶': 'ö',
    'Ã–': 'Ö',
    'Ã§': 'ç',
    'Ã‡': 'Ç',
    'Ä±': 'ı',
    'Ä°': 'İ',
    'ÄŸ': 'ğ',
    'Äž': 'Ğ',

    // Common punctuation
    '\u00E2\u20AC\u00A2': '•', // â€¢
    'â€¢': '•',
    '\u00E2\u20AC\u201C': '“',
    '\u00E2\u20AC\u201D': '”',
    '\u00E2\u20AC\u2018': '‘',
    '\u00E2\u20AC\u2019': '’',
    '\u00E2\u20AC\u2013': '–',
    '\u00E2\u20AC\u2014': '—',
    '\u00E2\u20AC\u2011': '‑', // â€‘
    'â€˜': '‘',
    'â€™': '’',
    'â€œ': '“',
    'â€': '”',
    'â€“': '–',
    'â€”': '—',
    'â€‘': '‑',

    // Artifacts
    '\u00C2': '', // Â
    'Â': '',
  };

  repl.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}
