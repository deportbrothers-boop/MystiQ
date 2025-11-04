import 'dart:convert';
import 'dart:io';

// Run with: dart tool/fix_encoding.dart
// It creates .bak backups and rewrites JSON files with cleaned UTF-8 strings.
void main() async {
  final dir = Directory('assets/i18n');
  if (!await dir.exists()) {
    print('assets/i18n not found');
    return;
  }
  final files = await dir
      .list()
      .where((e) => e is File && e.path.endsWith('.json'))
      .cast<File>()
      .toList();
  for (final f in files) {
    try {
      final raw = await f.readAsString();
      final jsonMap = json.decode(raw);
      final fixed = _fixJson(jsonMap);
      final pretty = const JsonEncoder.withIndent('  ').convert(fixed);
      final bak = File('${f.path}.bak');
      if (!await bak.exists()) {
        await f.copy(bak.path);
      }
      await f.writeAsString(pretty, encoding: utf8);
      print('Fixed: ${f.path}');
    } catch (e) {
      print('Skip ${f.path}: $e');
    }
  }
}

dynamic _fixJson(dynamic value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(_fixStr(k), _fixJson(v)));
  } else if (value is List) {
    return value.map(_fixJson).toList();
  } else if (value is String) {
    return _fixStr(value);
  }
  return value;
}

String _fixStr(String s) {
  if (s.isEmpty) return s;
  final suspect = RegExp(r'[ÃÂ�]');
  if (!suspect.hasMatch(s)) return s;
  var prev = s;
  for (var i = 0; i < 4; i++) {
    try {
      final bytes = latin1.encode(prev);
      final decoded = utf8.decode(bytes, allowMalformed: true);
      if (decoded == prev) break;
      prev = decoded;
    } catch (_) {
      break;
    }
  }
  const mapRepl = <String, String>{
    'Ã¼': 'ü', 'Ãœ': 'Ü', 'Ã¶': 'ö', 'Ã–': 'Ö', 'Ã§': 'ç', 'Ã‡': 'Ç',
    'Ã±': 'ñ', 'Ã¡': 'á', 'Ã©': 'é', 'Ã­': 'í', 'Ã³': 'ó', 'Ãº': 'ú',
    'Ä±': 'ı', 'Ä°': 'İ', 'ÅŸ': 'ş', 'Åž': 'Ş', 'ÄŸ': 'ğ', 'Äž': 'Ğ',
    'â€“': '–', 'â€”': '—', 'â€˜': '‘', 'â€™': '’', 'â€œ': '“', 'â€�': '”', 'â€¦': '…',
    '±': 'ı', 'Â ': '', 'Â': '',
  };
  var out = prev;
  mapRepl.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

