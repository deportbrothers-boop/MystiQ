import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final langs = ['tr', 'en', 'es', 'ar'];
  final results = <String, Map<String, String>>{};

  for (final code in langs) {
    results[code] = await _loadEffectiveMap(code);
  }

  final union = <String>{};
  for (final m in results.values) { union.addAll(m.keys); }

  stdout.writeln('I18N AUDIT (effective, after overlays)');
  for (final code in langs) {
    stdout.writeln('- ' + code + ': ' + results[code]!.length.toString() + ' keys');
  }
  stdout.writeln('- union: ' + union.length.toString() + ' keys');
  stdout.writeln('');

  for (final code in langs) {
    final miss = union.difference(results[code]!.keys.toSet());
    stdout.writeln('Missing in ' + code + ': ' + miss.length.toString());
    if (miss.isNotEmpty) {
      var shown = 0;
      for (final k in miss) {
        stdout.writeln('  - ' + k);
        shown++;
        if (shown >= 40) break;
      }
      if (miss.length > 40) stdout.writeln('  ... (' + (miss.length - 40).toString() + ' more)');
    }
    stdout.writeln('');
  }

  stdout.writeln('Placeholder consistency mismatches (first 60):');
  var printed = 0;
  for (final k in union) {
    final sets = <String>{};
    for (final code in langs) {
      final v = results[code]![k];
      if (v == null) continue;
      sets.add(_placeholdersOf(v).join(','));
    }
    if (sets.length > 1) {
      stdout.writeln('  * ' + k + ' => ' + sets.join(' | '));
      printed++;
      if (printed >= 60) break;
    }
  }
  stdout.writeln('');

  stdout.writeln('Mojibake scan (Ã, Â, â, �) — first 60 keys per lang:');
  for (final code in langs) {
    var count = 0;
    stdout.writeln('  [' + code + ']');
    final map = results[code]!;
    for (final e in map.entries) {
      final s = e.value;
      if (s.contains('Ã') || s.contains('Â') || s.contains('â') || s.contains('�')) {
        stdout.writeln('   - ' + e.key + ': ' + s.replaceAll('\n', ' '));
        count++;
        if (count >= 60) break;
      }
    }
    if (count == 0) stdout.writeln('   (none)');
  }
}

Future<Map<String, String>> _loadEffectiveMap(String code) async {
  final m = <String, String>{};
  Future<void> _merge(String path) async {
    final f = File(path);
    if (await f.exists()) {
      final txt = await f.readAsString();
      final j = json.decode(txt) as Map<String, dynamic>;
      j.forEach((k, v) {
        if (v is String && v.isNotEmpty) m[k] = v;
      });
    }
  }

  if (code == 'tr') {
    await _merge('assets/i18n/premium_tr.json');
    await _merge('assets/i18n/live_extra_tr.json');
    await _merge('assets/i18n/deep_tr.json');
    await _merge('assets/i18n/tr_tone.json');
    await _merge('assets/i18n/tr.json');
    final en = await _loadEffectiveMap('en');
    en.forEach((k, v) { m.putIfAbsent(k, () => v); });
  } else {
    await _merge('assets/i18n/' + code + '.json');
    await _merge('assets/i18n/premium_' + code + '.json');
    await _merge('assets/i18n/' + code + '_tone.json');
  }
  return m;
}

List<String> _placeholdersOf(String s) {
  final re = RegExp(r'\{([a-zA-Z0-9_]+)\}');
  return re.allMatches(s).map((m) => m.group(1)!).toSet().toList()..sort();
}

