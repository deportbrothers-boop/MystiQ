import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../../features/profile/user_profile.dart';
import 'local_generator.dart';

class AiConfig {
  final String serverUrl;
  final String streamUrl; // optional
  final String model;
  final String appToken; // optional
  AiConfig({required this.serverUrl, required this.model, this.streamUrl = '', this.appToken = ''});
  static Future<AiConfig> load() async {
    try {
      final txt = await rootBundle.loadString('assets/config/ai.json');
      final j = json.decode(txt) as Map<String, dynamic>;
      return AiConfig(
        serverUrl: (j['serverUrl'] ?? '') as String,
        model: (j['model'] ?? 'gpt-4o-mini') as String,
        streamUrl: (j['streamUrl'] ?? '') as String,
        appToken: (j['appToken'] ?? '') as String,
      );
    } catch (_) {
      return AiConfig(serverUrl: '', model: 'gpt-4o-mini');
    }
  }
}

class AiService {
  // ignore: unused_field
  static String? _apiKey; // --dart-define=OPENAI_API_KEY

  static void configure({String? openAIApiKey}) {
    _apiKey = openAIApiKey ?? const String.fromEnvironment('OPENAI_API_KEY');
  }

  static Future<String> generate({
    required String type,
    required UserProfile profile,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async {
    // Optional remote server
    final cfg = await AiConfig.load();
    var server = cfg.serverUrl;
    // Android emulator uses 10.0.2.2 for host loopback
    if (server.contains('127.0.0.1') && Platform.isAndroid) {
      server = server.replaceAll('127.0.0.1', '10.0.2.2');
    }
    if (server.isNotEmpty) {
      try {
        final r = await http.post(
          Uri.parse(server),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            if (cfg.appToken.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer ${cfg.appToken}',
          },
          body: json.encode({
            'type': type,
            'profile': profile.toJson(),
            'inputs': await _prepareInputs(extras),
            'locale': locale,
            'context': _contextInfo(locale: locale),
            'model': cfg.model,
          }),
        );
        final j = json.decode(r.body) as Map<String, dynamic>;
        final text = (j['text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) return text;
      } catch (_) {}
    }

    // Template-based fallback (i18n-driven) to avoid legacy mojibake
    if (extras != null && extras['i18n'] is Map) {
      final Map<String, dynamic> i18n = Map<String, dynamic>.from(extras['i18n'] as Map);
      String? tpl = i18n['ai.template.$type'] as String?;
      if (tpl != null && tpl.isNotEmpty) {
        var out = tpl;
        out = out.replaceAll('{name}', (profile.name.isEmpty) ? (i18n['ai.dear_soul'] as String? ?? 'Dear soul') : profile.name);
        final now = DateTime.now();
        final dow = _weekdayName(locale: locale, weekday: now.weekday);
        out = out.replaceAll('{dow}', dow);
        out = out.replaceAll('{zodiac}', profile.zodiac.isEmpty ? 'sign' : profile.zodiac);
        if (extras['cards'] is List) {
          final cards = (extras['cards'] as List).map((e) => '$e').toList();
          out = out.replaceAll('{cards}', cards.join(', '));
        }
        return out;
      }
    }
    // Fallback local generator
    return LocalAIGenerator.generate(type: type, profile: profile, extras: extras, locale: locale);
  }

  // Live chat streaming (local streaming if no API key). Options allow tone/length.
  static Stream<String> streamLiveChat({
    required UserProfile profile,
    required List<Map<String, dynamic>> history,
    required String text,
    String locale = 'tr',
    Map<String, dynamic>? options,
  }) async* {
    final base = LocalAIGenerator.generate(
      type: 'live_chat',
      profile: profile,
      extras: {'text': text, 'history': history, if (options != null) ...options},
      locale: locale,
    );
    final words = base.split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      buffer.write(words[i]);
      if (i < words.length - 1) buffer.write(' ');
      if (i % 6 == 0 || i == words.length - 1) {
        yield buffer.toString();
        await Future.delayed(const Duration(milliseconds: 18));
      }
    }
    yield "${buffer.toString()}\n\nNot: Bu sohbet eğlence amaçlıdır; kararlarında iç sezgini ve gerekirse uzman görüşünü izle.";
  }

  // Simple text streaming for readings. Tries remote stream, falls back to local chunking.
  static Stream<String> streamGenerate({
    required String type,
    required UserProfile profile,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async* {
    // Try remote streaming if configured
    final cfg = await AiConfig.load();
    var streamUrl = cfg.streamUrl;
    if (streamUrl.contains('127.0.0.1') && Platform.isAndroid) {
      streamUrl = streamUrl.replaceAll('127.0.0.1', '10.0.2.2');
    }
    if (streamUrl.isNotEmpty) {
      try {
        final req = {
          'type': type,
          'profile': profile.toJson(),
          'inputs': await _prepareInputs(extras),
          'locale': locale,
          'context': _contextInfo(locale: locale),
          'model': cfg.model,
        };

        // Prefer true streaming via a streamed request; falls back to whole-body if server buffers
        final client = http.Client();
        try {
          final httpReq = http.Request('POST', Uri.parse(streamUrl));
          httpReq.headers[HttpHeaders.contentTypeHeader] = 'application/json';
          if (cfg.appToken.isNotEmpty) httpReq.headers[HttpHeaders.authorizationHeader] = 'Bearer ${cfg.appToken}';
          httpReq.body = json.encode(req);
          final streamed = await client
              .send(httpReq)
              .timeout(const Duration(seconds: 12));
          if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
            final buf = StringBuffer();
            var carry = '';
            await for (final chunk in streamed.stream.transform(const Utf8Decoder())) {
              // Try to parse SSE-like lines first; otherwise, treat as plain text stream
              final combined = carry + chunk;
              final lines = combined.split(RegExp('\\r?\\n'));
              carry = lines.isNotEmpty ? lines.removeLast() : '';
              for (final raw in lines) {
                final line = raw.trim();
                if (line.isEmpty) continue;
                String piece = line;
                if (piece.startsWith('data:')) {
                  piece = piece.substring(5).trim();
                  // If server sends JSON chunks, try to extract a text field
                  try {
                    final j = json.decode(piece);
                    final val = (j is Map<String, dynamic>)
                        ? (j['delta'] ?? j['text'] ?? j['content'] ?? j['data'])
                        : null;
                    if (val is String) piece = val;
                  } catch (_) {
                    // not JSON; keep raw piece
                  }
                }
                if (piece.isEmpty) continue;
                // Accumulate to a growing buffer and yield progressively
                if (buf.isNotEmpty) buf.write(' ');
                buf.write(piece);
                yield buf.toString();
              }
            }
            if (carry.trim().isNotEmpty) {
              if (buf.isNotEmpty) buf.write(' ');
              buf.write(carry.trim());
              yield buf.toString();
            }
            client.close();
            return; // completed remote streaming
          } else {
            // Fallback to non-streaming single body if status not OK
            final r = await http
                .post(
                  Uri.parse(streamUrl),
                  headers: {
                    HttpHeaders.contentTypeHeader: 'application/json',
                    if (cfg.appToken.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer ${cfg.appToken}',
                  },
                  body: json.encode(req),
                )
                .timeout(const Duration(seconds: 12));
            final body = r.body.trim();
            if (body.isNotEmpty) {
              final parts = body.split(RegExp("\\s+"));
              final buf = StringBuffer();
              for (var i = 0; i < parts.length; i++) {
                buf.write(parts[i]);
                if (i < parts.length - 1) buf.write(' ');
                if (i % 6 == 0 || i == parts.length - 1) {
                  yield buf.toString();
                  await Future.delayed(const Duration(milliseconds: 16));
                }
              }
              return;
            }
            client.close();
          }
        } on TimeoutException {
          try {
            client.close();
          } catch (_) {}
          // Fall through to local generation
        } finally {
          // Ensure client closed even if exceptions occur
          try { client.close(); } catch (_) {}
        }
      } catch (_) {}
    }

    final full = await generate(type: type, profile: profile, extras: extras, locale: locale);
    final parts = full.split(' ');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      buf.write(parts[i]);
      if (i < parts.length - 1) buf.write(' ');
      if (i % 6 == 0 || i == parts.length - 1) {
        yield buf.toString();
        await Future.delayed(const Duration(milliseconds: 16));
      }
    }
  }

  static Future<Map<String, dynamic>> _prepareInputs(Map<String, dynamic>? extras) async {
    extras ??= {};
    final out = <String, dynamic>{};
    if (!kIsWeb && extras['imagePaths'] is List && (extras['imagePaths'] as List).isNotEmpty) {
      final paths = (extras['imagePaths'] as List).whereType<String>().toList();
      final b64s = <String>[];
      for (final p in paths) {
        try {
          final bytes = await File(p).readAsBytes();
          b64s.add(base64Encode(bytes));
        } catch (_) {}
      }
      if (b64s.isNotEmpty) out['imageBase64s'] = b64s;
    }
    if (!kIsWeb && extras['imagePath'] is String) {
      try {
        final bytes = await File(extras['imagePath'] as String).readAsBytes();
        out['imageBase64'] = base64Encode(bytes);
      } catch (_) {}
    }
    if (extras['cards'] is List) {
      final names = (extras['cards'] as List).map((e) => '$e').toList();
      // If reversed flags are present, annotate names accordingly so server can reflect it in text
      if (extras['reversed'] is List) {
        final revs = (extras['reversed'] as List)
            .map((e) {
              if (e is bool) return e;
              final s = '$e'.toLowerCase();
              return s == 'true' || s == '1' || s == 'yes';
            })
            .toList();
        for (var i = 0; i < names.length && i < revs.length; i++) {
          if (revs[i] == true) names[i] = '${names[i]} (reversed)';
        }
      }
      out['text'] = 'Tarot cards: ${names.join(', ')}';
    } else if (extras['text'] != null) {
      out['text'] = extras['text'];
    }
    // Pass through optional numeric/contextual hints for better grounding
    if (extras.containsKey('energy')) out['energy'] = extras['energy'];
    if (extras.containsKey('length')) out['length'] = extras['length'];
    if (extras.containsKey('premium')) out['premium'] = extras['premium'];
    return out;
  }

  static Map<String, dynamic> _contextInfo({String locale = 'tr'}) {
    final now = DateTime.now();
    return {
      'now': now.toIso8601String(),
      'weekday': now.weekday,
      'dayOfYear': int.parse('${now.difference(DateTime(now.year)).inDays + 1}'),
      'locale': locale,
      'app': 'MystiQ',
    };
  }
}

String _weekdayName({required String locale, required int weekday}) {
  // 1..7 Monday..Sunday per Dart DateTime
  final tr = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  final en = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final es = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  final ar = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  List<String> names;
  switch (locale) {
    case 'tr': names = tr; break;
    case 'es': names = es; break;
    case 'ar': names = ar; break;
    default: names = en; break;
  }
  final idx = ((weekday - 1) % 7).clamp(0, 6);
  return names[idx];
}
