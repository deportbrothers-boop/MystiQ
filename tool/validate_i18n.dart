import 'dart:convert';
import 'dart:io';

void main() {
  final dir = Directory('assets/i18n');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final maps = <String, Map<String, dynamic>>{};
  for (final f in files) {
    final code = f.uri.pathSegments.last.split('.').first;
    final text = f.readAsStringSync();
    try {
      maps[code] = json.decode(text) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('Invalid JSON: ${f.path}: $e');
      exitCode = 1;
    }
  }

  if (maps.isEmpty) {
    stderr.writeln('No i18n JSON files found.');
    exit(1);
  }

  final allKeys = <String>{};
  maps.values.forEach((m) => allKeys.addAll(m.keys));

  final baseline = maps['en'] ?? maps.values.first;
  final missing = <String, List<String>>{}; // key -> langs
  for (final k in allKeys) {
    for (final entry in maps.entries) {
      if (!entry.value.containsKey(k)) {
        missing.putIfAbsent(k, () => []).add(entry.key);
      }
    }
  }

  if (missing.isEmpty) {
    stdout.writeln('All localization files share the same keys.');
    return;
  }

  stdout.writeln('Missing keys by language:');
  for (final e in missing.entries) {
    stdout.writeln('  ${e.key}: ${e.value.join(', ')}');
  }
  exitCode = 2;
}

