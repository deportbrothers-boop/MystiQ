import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/profile/user_profile.dart';
import '../access/ai_generation_guard.dart';
import 'local_generator.dart';

class AiConfig {
  final String serverUrl;
  final String streamUrl;
  final String model;
  final String appToken;
  AiConfig({
    required this.serverUrl,
    required this.model,
    this.streamUrl = '',
    this.appToken = '',
  });
  static Future<AiConfig> load() async {
    var server = const String.fromEnvironment('AI_SERVER_URL', defaultValue: '');
    var stream = const String.fromEnvironment('AI_STREAM_URL', defaultValue: '');
    var model = const String.fromEnvironment('AI_MODEL', defaultValue: 'gpt-4o-mini');
    var token = const String.fromEnvironment('AI_APP_TOKEN', defaultValue: '');
    Map<String, dynamic>? j;
    try {
      final txt = await rootBundle.loadString('assets/config/ai.json');
      j = json.decode(txt) as Map<String, dynamic>;
    } catch (_) {}
    server = server.isNotEmpty ? server : (j?['serverUrl'] ?? '') as String? ?? '';
    stream = stream.isNotEmpty ? stream : (j?['streamUrl'] ?? '') as String? ?? '';
    model = model.isNotEmpty ? model : (j?['model'] ?? 'gpt-4o-mini') as String? ?? 'gpt-4o-mini';
    token = token.isNotEmpty ? token : (j?['appToken'] ?? '') as String? ?? '';
    if (token.startsWith('UZUN_') || token.toLowerCase().contains('token')) {
      token = '';
    }
    return AiConfig(serverUrl: server, model: model, streamUrl: stream, appToken: token);
  }
}

class AiService {
  static String? _apiKey;

  static void configure({String? openAIApiKey}) {
    _apiKey = openAIApiKey ?? const String.fromEnvironment('OPENAI_API_KEY');
  }

  static Future<String> generate({
    required String type,
    required UserProfile profile,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async {
    const guardedTypes = {'coffee', 'tarot', 'palm', 'dream', 'astro'};
    if (guardedTypes.contains(type)) {
      final permit = (extras?['permit'] ?? '').toString().trim();
      if (permit.isEmpty) {
        throw const AiGenerationGuardException('missing_permit');
      }
      final ok = await AiGenerationGuard.consumePermit(permit);
      if (!ok) {
        throw const AiGenerationGuardException('permit_already_consumed');
      }
    }

    if (type == 'coffee') {
      return _generateCoffee(profile: profile, extras: extras, locale: locale);
    }
    if (type == 'tarot') {
      return _generateTarot(profile: profile, extras: extras, locale: locale);
    }
    if (type == 'palm' || type == 'dream' || type == 'astro') {
      return _generateLongSymbolic(type: type, profile: profile, extras: extras, locale: locale);
    }

    try {
      return LocalAIGenerator.generate(type: type, profile: profile, extras: extras, locale: locale);
    } catch (_) {
      return 'Üretim şu anda yapılamıyor. Lütfen biraz sonra tekrar dene.\n\nBu içerik eğlence amaçlıdır; kesinlik içermez.';
    }
  }

  static const int _coffeeMinChars = 200;
  static const int _coffeeMaxChars = 5000;
  static const int _tarotMinChars = 900;
  static const int _tarotMaxChars = 1500;
  static const int _longMinChars = 900;
  static const int _longMaxChars = 1500;
  static const String _coffeeIntroSigKey = 'coffee_intro_sig_v1';
  static const Duration _httpRequestTimeout = Duration(seconds: 120);

  static Future<String?> _loadCoffeeIntroSig() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = sp.getString(_coffeeIntroSigKey);
      if (v == null || v.trim().isEmpty) return null;
      return v.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCoffeeIntroSig(String sig) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_coffeeIntroSigKey, sig);
    } catch (_) {}
  }

  static String _sigFromIntro(String s) {
    final oneLine = s.replaceAll('\r\n', '\n').split('\n').first.trim().toLowerCase();
    return oneLine.length <= 120 ? oneLine : oneLine.substring(0, 120);
  }

  static Future<String?> _tryRemoteOnce({
    required String type,
    required UserProfile profile,
    required Map<String, dynamic> extras,
    required String locale,
    required AiConfig cfg,
    required int attempt,
  }) async {
    var server = cfg.serverUrl;
    if (server.contains('127.0.0.1') && Platform.isAndroid) {
      server = server.replaceAll('127.0.0.1', '10.0.2.2');
    }
    if (server.isEmpty) return null;

    final payload = {
      'type': type,
      'profile': profile.toJson(),
      'inputs': await _prepareInputs(extras),
      'locale': locale,
      'context': _contextInfo(locale: locale),
      'model': cfg.model,
      'temperature': attempt == 0 ? 0.8 : 0.9,
      'presence_penalty': 0.9,
      'frequency_penalty': 0.4,
    };

    try {
      debugPrint('PAYLOAD_DEBUG: ${jsonEncode(payload)}');
      final r = await http.post(
        Uri.parse(server),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          if (cfg.appToken.isNotEmpty)
            HttpHeaders.authorizationHeader: 'Bearer ${cfg.appToken}',
        },
        body: json.encode(payload),
      ).timeout(_httpRequestTimeout);
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final j = json.decode(r.body) as Map<String, dynamic>;
        final text = (j['text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) return text;
      }
    } catch (_) {}
    return null;
  }

  // *** KAHVE: Server metnini direkt kullan, local generator'a düşme ***
  static Future<String> _generateCoffee({
    required UserProfile profile,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async {
    final cfg = await AiConfig.load();
    final prevSig = await _loadCoffeeIntroSig();
    final userName = profile.name.trim().isEmpty ? 'Dostum' : profile.name.trim();

    final baseExtras = <String, dynamic>{
      ...(extras ?? const <String, dynamic>{}),
      'typeHint': 'coffee',
      if (prevSig != null) 'prevIntroSig': prevSig,
      'userName': userName,
    };

    // Önce server'dan dene — başarılı olursa direkt döndür
    for (var attempt = 0; attempt < 3; attempt++) {
      final attemptExtras = <String, dynamic>{...baseExtras, 'attempt': attempt};
      final raw = await _tryRemoteOnce(
        type: 'coffee',
        profile: profile,
        extras: attemptExtras,
        locale: locale,
        cfg: cfg,
        attempt: attempt,
      );

      if (raw != null && raw.trim().isNotEmpty) {
        // Server'dan metin geldi — doğrudan kullan, hiçbir post-processing yapma
        var out = raw.trim();
        if (!_containsCoffeeDisclaimer(out)) {
          out = '$out\n\n$_coffeeNeutralSuffix';
        }
        await _saveCoffeeIntroSig(_sigFromIntro(out));
        return out;
      }
    }

    // Server tamamen başarısız olursa local fallback
    final fallbackExtras = <String, dynamic>{...baseExtras, 'attempt': 0};
    final local = LocalAIGenerator.generate(
      type: 'coffee',
      profile: profile,
      extras: fallbackExtras,
      locale: locale,
    );
    var out = local.trim();
    if (!_containsCoffeeDisclaimer(out)) {
      out = '$out\n\n$_coffeeNeutralSuffix';
    }
    await _saveCoffeeIntroSig(_sigFromIntro(out));
    return out;
  }

  static Future<String> _generateTarot({
    required UserProfile profile,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async {
    final cfg = await AiConfig.load();
    final userName = profile.name.trim().isEmpty ? 'Dostum' : profile.name.trim();

    final baseExtras = <String, dynamic>{
      ...(extras ?? const <String, dynamic>{}),
      'userName': userName,
      'tarotPolicy': {'minChars': _tarotMinChars, 'maxChars': _tarotMaxChars},
    };

    String last = '';
    for (var attempt = 0; attempt < 3; attempt++) {
      final attemptExtras = <String, dynamic>{...baseExtras, 'attempt': attempt};
      final raw = await _tryRemoteOnce(
            type: 'tarot',
            profile: profile,
            extras: attemptExtras,
            locale: locale,
            cfg: cfg,
            attempt: attempt,
          ) ??
          LocalAIGenerator.generate(type: 'tarot', profile: profile, extras: attemptExtras, locale: locale);

      var out = postProcessTarotText(raw);

      if (out.length < _tarotMinChars) {
        try {
          final extra = LocalAIGenerator.generate(
            type: 'tarot',
            profile: profile,
            extras: {...attemptExtras, 'attempt': attempt + 7},
            locale: locale,
          );
          out = postProcessTarotText('$out\n\n$extra');
        } catch (_) {}
      }

      last = _clampToRange(out, min: _tarotMinChars, max: _tarotMaxChars);
      if (last.length >= _tarotMinChars && last.length <= _tarotMaxChars) return last;
    }

    return last.isNotEmpty
        ? last
        : 'Tarot\n\nYorum şu anda oluşturulamadı.\n\n$_coffeeNeutralSuffix';
  }

  static Future<String> _generateLongSymbolic({
    required String type,
    required UserProfile profile,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async {
    final cfg = await AiConfig.load();
    final userName = profile.name.trim().isEmpty ? 'Dostum' : profile.name.trim();

    final baseExtras = <String, dynamic>{
      ...(extras ?? const <String, dynamic>{}),
      'userName': userName,
      'typeHint': type,
      'symbolicPolicy': {'minChars': _longMinChars, 'maxChars': _longMaxChars, 'noFuture': true},
    };

    String last = '';
    for (var attempt = 0; attempt < 3; attempt++) {
      final attemptExtras = <String, dynamic>{...baseExtras, 'attempt': attempt};
      final raw = await _tryRemoteOnce(
            type: type,
            profile: profile,
            extras: attemptExtras,
            locale: locale,
            cfg: cfg,
            attempt: attempt,
          ) ??
          LocalAIGenerator.generate(type: type, profile: profile, extras: attemptExtras, locale: locale);

      var out = postProcessSymbolicText(raw);

      if (out.length < _longMinChars) {
        try {
          final extra = LocalAIGenerator.generate(
            type: type,
            profile: profile,
            extras: {...attemptExtras, 'attempt': attempt + 7},
            locale: locale,
          );
          out = postProcessSymbolicText('$out\n\n$extra');
        } catch (_) {}
      }

      last = _clampToRange(out, min: _longMinChars, max: _longMaxChars);
      if (last.length >= _longMinChars && last.length <= _longMaxChars) return last;
    }

    return last.isNotEmpty
        ? last
        : '${_titleForTypeTr(type)}\n\nYorum şu anda oluşturulamadı.\n\n$_coffeeNeutralSuffix';
  }

  static Stream<String> streamLiveChat({
    required UserProfile profile,
    required List<Map<String, dynamic>> history,
    required String text,
    String locale = 'tr',
    Map<String, dynamic>? options,
  }) async* {
    final full = await generate(
      type: 'live_chat',
      profile: profile,
      extras: {'text': text, 'history': history, if (options != null) ...options},
      locale: locale,
    );
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

  static Stream<String> streamGenerate({
    required String type,
    required UserProfile profile,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) async* {
    if (type != 'coffee' && type != 'tarot') {
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
      return;
    }

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

        final client = http.Client();
        try {
          final httpReq = http.Request('POST', Uri.parse(streamUrl));
          httpReq.headers[HttpHeaders.contentTypeHeader] = 'application/json';
          if (cfg.appToken.isNotEmpty)
            httpReq.headers[HttpHeaders.authorizationHeader] = 'Bearer ${cfg.appToken}';
          httpReq.body = json.encode(req);
          final streamed = await client.send(httpReq).timeout(_httpRequestTimeout);
          if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
            final buf = StringBuffer();
            var carry = '';
            await for (final chunk in streamed.stream.transform(const Utf8Decoder())) {
              final combined = carry + chunk;
              final lines = combined.split(RegExp('\\r?\\n'));
              carry = lines.isNotEmpty ? lines.removeLast() : '';
              for (final raw in lines) {
                final line = raw.trim();
                if (line.isEmpty) continue;
                String piece = line;
                if (piece.startsWith('data:')) {
                  piece = piece.substring(5);
                  try {
                    final j = json.decode(piece);
                    final val = (j is Map<String, dynamic>)
                        ? (j['delta'] ?? j['text'] ?? j['content'] ?? j['data'])
                        : null;
                    if (val is String) piece = val;
                  } catch (_) {}
                }
                if (piece.isEmpty) continue;
                buf.write(piece);
                yield buf.toString();
              }
            }
            if (carry.isNotEmpty) {
              buf.write(carry);
              yield buf.toString();
            }
            client.close();
            return;
          } else {
            final r = await http.post(
              Uri.parse(streamUrl),
              headers: {
                HttpHeaders.contentTypeHeader: 'application/json',
                if (cfg.appToken.isNotEmpty)
                  HttpHeaders.authorizationHeader: 'Bearer ${cfg.appToken}',
              },
              body: json.encode(req),
            ).timeout(_httpRequestTimeout);
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
          try { client.close(); } catch (_) {}
        } finally {
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
      if (extras['reversed'] is List) {
        final revs = (extras['reversed'] as List).map((e) {
          if (e is bool) return e;
          final s = '$e'.toLowerCase();
          return s == 'true' || s == '1' || s == 'yes';
        }).toList();
        for (var i = 0; i < names.length && i < revs.length; i++) {
          if (revs[i] == true) names[i] = '${names[i]} (reversed)';
        }
      }
      out['text'] = 'Tarot cards: ${names.join(', ')}';
    } else if (extras['text'] != null) {
      out['text'] = extras['text'];
    }

    final typeHint = (extras['typeHint'] ?? '').toString();
    if (typeHint == 'coffee') {
      out['topic'] = extras['topic'] ?? '';
      out['styleHintTr'] = '';
      out['userName'] = (extras['userName'] ?? '').toString();
      out['length'] = 'long';
    }

    if (typeHint == 'dream' || typeHint == 'palm' || typeHint == 'astro') {
      final userName = (extras['userName'] ?? '').toString().trim();
      out['styleHintTr'] = 'Sistem yönergesi (zorunlu):\n'
          'Sen sembolik bir yorumlayıcısısın. Gelecek hakkında tahmin yapma. Tarih verme. Kesinlik iddiasında bulunma.\n'
          '"Olacak" yerine "çağrıştırıyor/izlenim veriyor/sembol olarak yorumlanabilir" kullan.\n'
          'Yorumların yalnızca eğlence amaçlı sembolik çağrışımlara dayanmalı.\n'
          'Uzunluk: 900–1500 karakter; 4–5 kısa paragraf, akıcı anlatım.\n'
          'Yasaklar: tarih/süre, "yakında/ileride/gelecekte", kesinlik/garanti.\n'
          'En alt satır: "Bu içerik eğlence amaçlıdır; kesinlik içermez."';
      out['userName'] = userName;
      out['length'] = 'long';
      out['formatHint'] = 'symbolic_policy_v1';
    }

    if (extras.containsKey('energy')) out['energy'] = extras['energy'];
    if (extras.containsKey('length')) out['length'] = extras['length'];
    if (extras.containsKey('premium')) out['premium'] = extras['premium'];
    return out;
  }

  static const String _coffeeNeutralSuffix = 'Bu içerik eğlence amaçlıdır; kesinlik içermez.';

  static String postProcessCoffeeText(String input) {
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.isEmpty) out = 'Kahve Yorumu\n\nFincandaki şekiller sembolik çağrışımlar veriyor.';
    if (!_containsCoffeeDisclaimer(out)) {
      out = '$out\n\n$_coffeeNeutralSuffix';
    }
    return out;
  }

  static String postProcessTarotText(String input) {
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.isEmpty) out = 'Tarot\n\nKartlar sembolik çağrışımlar veriyor.';
    if (!_containsCoffeeDisclaimer(out)) {
      out = '$out\n\n$_coffeeNeutralSuffix';
    }
    return out;
  }

  static String postProcessSymbolicText(String input) {
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.isEmpty) out = 'Yorum\n\nSemboller sembolik çağrışımlar veriyor.';
    if (!_containsCoffeeDisclaimer(out)) {
      out = '$out\n\n$_coffeeNeutralSuffix';
    }
    return out;
  }

  static String _titleForTypeTr(String type) {
    switch (type) {
      case 'dream': return 'Rüya Tabiri';
      case 'palm': return 'El Çizgisi Yorumu';
      case 'astro': return 'Astroloji';
      case 'tarot': return 'Tarot';
      case 'coffee': return 'Kahve Yorumu';
      default: return 'Yorum';
    }
  }

  static String _clampToRange(String s, {required int min, required int max}) {
    var out = s.replaceAll('\r\n', '\n').trim();
    if (out.length <= max) return out;
    final cut = out.substring(0, max);
    final para = cut.lastIndexOf('\n\n');
    if (para > 320) return cut.substring(0, para).trimRight();
    final lastDot = _lastIndexOfAny(cut, const ['.', '!', '?']);
    if (lastDot > 320) return cut.substring(0, lastDot + 1).trimRight();
    return cut.trimRight();
  }

  static int _lastIndexOfAny(String s, List<String> needles) {
    var best = -1;
    for (final n in needles) {
      final i = s.lastIndexOf(n);
      if (i > best) best = i;
    }
    return best;
  }

  static bool _containsCoffeeDisclaimer(String text) {
    final lower = text.toLowerCase();
    return lower.contains('eğlence amaçlıdır') || lower.contains('eglence amaclidir');
  }

  static Map<String, dynamic> _contextInfo({String locale = 'tr'}) {
    final now = DateTime.now();
    return {
      'now': now.toIso8601String(),
      'weekday': now.weekday,
      'dayOfYear': int.parse('${now.difference(DateTime(now.year)).inDays + 1}'),
      'locale': locale,
      'app': 'Falla',
    };
  }
}