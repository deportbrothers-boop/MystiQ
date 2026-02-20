import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/profile/user_profile.dart';
import '../access/ai_generation_guard.dart';
import 'local_generator.dart';

class AiConfig {
  final String serverUrl;
  final String streamUrl; // optional
  final String model;
  final String appToken; // optional
  AiConfig({required this.serverUrl, required this.model, this.streamUrl = '', this.appToken = ''});
  static Future<AiConfig> load() async {
    // Prefer compile-time overrides to avoid bundling gizli anahtarlar
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
    // Strip obvious placeholder tokens to keep release paketlerinde gizli anahtar saklanmamasi
    if (token.startsWith('UZUN_') || token.toLowerCase().contains('token')) {
      token = '';
    }
    return AiConfig(serverUrl: server, model: model, streamUrl: stream, appToken: token);
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
    // Guard: Never generate a reading without an issued permit.
    // Permit is granted after either watching 2 rewarded ads or spending coins.
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

    // Diğer içerikler: yerel üretim.
    try {
      return LocalAIGenerator.generate(
        type: type,
        profile: profile,
        extras: extras,
        locale: locale,
      );
    } catch (_) {
      return 'Üretim şu anda yapılamıyor. Lütfen biraz sonra tekrar dene.\n\nBu içerik eğlence amaçlıdır; kesinlik içermez.';
    }
  }

  static const int _coffeeMinChars = 900;
  static const int _coffeeMaxChars = 1500;
  static const int _tarotMinChars = 900;
  static const int _tarotMaxChars = 1500;
  static const int _longMinChars = 900;
  static const int _longMaxChars = 1500;
  static const String _coffeeIntroSigKey = 'coffee_intro_sig_v1';

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
      // Soft hints (server may ignore)
      'temperature': attempt == 0 ? 0.8 : 0.9,
      'presence_penalty': 0.9,
      'frequency_penalty': 0.4,
    };

    try {
      final r = await http
          .post(
            Uri.parse(server),
            headers: {
              HttpHeaders.contentTypeHeader: 'application/json',
              if (cfg.appToken.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer ${cfg.appToken}',
            },
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 35));
      if (r.statusCode >= 200 && r.statusCode < 300) {
        final j = json.decode(r.body) as Map<String, dynamic>;
        final text = (j['text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) return text;
      }
    } catch (_) {}
    return null;
  }

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
      // “Aynı giriş kalıbı” tekrarını azaltmak için server'a ipucu
      if (prevSig != null) 'prevIntroSig': prevSig,
      'userName': userName,
      'coffeePolicy': {
        'minChars': _coffeeMinChars,
        'maxChars': _coffeeMaxChars,
      },
    };

    String last = '';
    for (var attempt = 0; attempt < 3; attempt++) {
      final attemptExtras = <String, dynamic>{...baseExtras, 'attempt': attempt};
      final raw = await _tryRemoteOnce(
            type: 'coffee',
            profile: profile,
            extras: attemptExtras,
            locale: locale,
            cfg: cfg,
            attempt: attempt,
          ) ??
          LocalAIGenerator.generate(type: 'coffee', profile: profile, extras: attemptExtras, locale: locale);

      final formatted = _formatCoffeeReading(
        raw: raw,
        userName: userName,
        locale: locale,
        prevIntroSig: prevSig,
        attempt: attempt,
      );
      last = formatted;
      if (formatted.length >= _coffeeMinChars && formatted.length <= _coffeeMaxChars) {
        await _saveCoffeeIntroSig(_sigFromIntro(formatted));
        return formatted;
      }
    }

    await _saveCoffeeIntroSig(_sigFromIntro(last));
    return last;
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
      'tarotPolicy': {
        'minChars': _tarotMinChars,
        'maxChars': _tarotMaxChars,
      },
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
    required String type, // palm|dream|astro
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
      'symbolicPolicy': {
        'minChars': _longMinChars,
        'maxChars': _longMaxChars,
        'noFuture': true,
      },
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

  // Live chat streaming (local streaming if no API key). Options allow tone/length.
  static Stream<String> streamLiveChat({
    required UserProfile profile,
    required List<Map<String, dynamic>> history,
    required String text,
    String locale = 'tr',
    Map<String, dynamic>? options,
  }) async* {
    // Canlı sohbet: uzaktan AI kapalı (sadece yerel sembolik metin).
    final full = await generate(
      type: 'live_chat',
      profile: profile,
      extras: {
        'text': text,
        'history': history,
        if (options != null) ...options,
      },
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

  // Simple text streaming for readings. Tries remote stream, falls back to local chunking.
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
              .timeout(const Duration(seconds: 30));
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
                  piece = piece.substring(5);
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
                // Accumulate to a growing buffer and yield progressively without injecting spaces
                buf.write(piece);
                yield buf.toString();
              }
            }
            if (carry.isNotEmpty) {
              buf.write(carry);
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
                .timeout(const Duration(seconds: 30));
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
    // Coffee-style persona hint to make outputs feel like a real cup reading
    final typeHint = (extras['typeHint'] ?? '').toString();
    if (typeHint == 'coffee') {
      final prev = (extras['prevIntroSig'] ?? '').toString().trim();
      out['styleHintTr'] =
          'MYSTIQ – Kahve Yorumu çıktı kuralları:\n'
          '1) Kullanıcı adı mutlaka geçmeli: ilk paragraf "${(extras['userName'] ?? '').toString().trim()}, ..." diye başlamalı ve isim toplam 1–2 kez geçmeli.\n'
          '2) Uzunluk: 900–1500 karakter; 4–5 kısa paragraf akıcı anlatım.\n'
          '3) Ton: sıcak, samimi, sezgisel. Kesin hüküm yok; "olacak/kesin" yok. Gelecek tahmini yok.\n'
          '4) Yapı sırası: (A) Açılış (isim + fincanın genel havası + gün/ritim) '
          '(B) 2–3 şekil/iz + duygu diliyle yorum '
          '(C) Günün teması '
          '(D) "Bugünün Mini Önerileri:" altında 2 satır: 1 sosyal, 1 içsel '
          '(E) Kapanış + geri çağırma CTA.\n'
          '5) Kapanış CTA zorunlu: "fincanın/ kahve yorumunun sonuna geliyorken" hissi + tekrar çağır.\n'
          'Format zorunlu:\n'
          '- İlk satır: "Kahve Yorumu"\n'
          '- 4–5 paragraf\n'
          '- "Bugünün Mini Önerileri:" başlığı ve altında iki madde "- ..."\n'
          '- En alt satır: "Bu içerik eğlence amaçlıdır; kesinlik içermez."\n'
          'Yasaklar: tarih/süre vermek, "yakında/ileride/gelecekte", kesinlik/garanti.\n'
          '${prev.isNotEmpty ? 'Önceki giriş kalıbını tekrar etme: "$prev".\n' : ''}'
          'Çıktıda markdown/numaralı liste yok; sadece istenen başlık ve mini öneriler maddeleri var.';
      out['userName'] = (extras['userName'] ?? '').toString();
      out['length'] = 'long';
      out['formatHint'] = 'coffee_policy_v2';
    }

    // Other long symbolic readings (no future/certainty/timing)
    if (typeHint == 'dream' || typeHint == 'palm' || typeHint == 'astro') {
      final userName = (extras['userName'] ?? '').toString().trim();
      out['styleHintTr'] =
          'Sistem yönergesi (zorunlu):\n'
          'Sen sembolik bir yorumlayıcısısın. Gelecek hakkında tahmin yapma. Tarih verme. Kesinlik iddiasında bulunma.\n'
          '“Olacak” yerine “çağrıştırıyor/izlenim veriyor/sembol olarak yorumlanabilir” kullan.\n'
          'Yorumların yalnızca eğlence amaçlı sembolik çağrışımlara dayanmalı.\n'
          'Uzunluk: 900–1500 karakter; 4–5 kısa paragraf, akıcı anlatım.\n'
          'Yasaklar: tarih/süre, “yakında/ileride/gelecekte”, kesinlik/garanti.\n'
          'En alt satır: "Bu içerik eğlence amaçlıdır; kesinlik içermez."';
      out['userName'] = userName;
      out['length'] = 'long';
      out['formatHint'] = 'symbolic_policy_v1';
    }
    // Pass through optional numeric/contextual hints for better grounding
    if (extras.containsKey('energy')) out['energy'] = extras['energy'];
    if (extras.containsKey('length')) out['length'] = extras['length'];
    if (extras.containsKey('premium')) out['premium'] = extras['premium'];
    return out;
  }

  static const String _coffeeNeutralSuffix = 'Bu içerik eğlence amaçlıdır; kesinlik içermez.';
  static final RegExp _coffeeBannedWordRe = RegExp(
    r'\\b(olacak|olacaklar|kesin|garanti|mutlaka|yakinda|yakında|ileride|gelecekte|su\\s+tarihte|şu\\s+tarihte)\\b',
    caseSensitive: false,
  );
  static final RegExp _coffeeDateRe = RegExp(r'\\b\\d{1,2}[./-]\\d{1,2}([./-]\\d{2,4})?\\b', caseSensitive: false);
  static final RegExp _coffeeMonthRe = RegExp(
    r'\\b\\d{1,2}\\s*(ocak|subat|şubat|mart|nisan|mayıs|mayis|haziran|temmuz|ağustos|agustos|eylül|eylul|ekim|kasım|kasim|aralık|aralik)\\b',
    caseSensitive: false,
  );
  static final RegExp _coffeeTimeRe = RegExp(
    r'\\b(\\d{1,2}:\\d{2}|\\d{1,3}\\s*(gün|gun|hafta|ay|yıl|yil|saat|dakika|dk))\\b',
    caseSensitive: false,
  );
  static final RegExp _coffeeRelativeRe = RegExp(
    r'\\b(\\d+|bir|iki|uc|üç|dort|beş|bes|alti|yedi|sekiz|dokuz|on)\\s*(gün|gun|hafta|ay|yıl|yil|saat|dakika|dk)\\s*(sonra|icinde|içinde)?\\b',
    caseSensitive: false,
  );

  static String postProcessCoffeeText(String input) {
    // Bu fonksiyon artık formatı bozmayacak şekilde minimal temizlik yapar.
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.isEmpty) out = 'Kahve Yorumu\n\nFincandaki şekiller sembolik çağrışımlar veriyor.';

    // Banned/time cümleleri temizle (satır bazlı, mini öneri madde satırlarını koru)
    final lines = out.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final t = line.trimRight();
      if (t.trim().isEmpty) { kept.add(''); continue; }
      // Mini öneriler satırları kısa ve güvenli olmalı; filtrelemeden geçir ama yapıyı koru
      if (_shouldDropCoffeeSentence(t)) continue;
      kept.add(t);
    }
    out = kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    // En altta zorunlu uyarı
    if (!_containsCoffeeDisclaimer(out)) {
      out = out.trimRight();
      if (!out.endsWith(_coffeeNeutralSuffix)) {
        out = '$out\n\n$_coffeeNeutralSuffix';
      }
    }
    return out;
  }

  static String postProcessTarotText(String input) {
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.isEmpty) out = 'Tarot\n\nKartlar sembolik çağrışımlar veriyor.';

    final lines = out.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final t = line.trimRight();
      if (t.trim().isEmpty) { kept.add(''); continue; }
      if (_shouldDropCoffeeSentence(t)) continue;
      kept.add(t);
    }
    out = kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    if (!_containsCoffeeDisclaimer(out)) {
      out = '$out\n\n$_coffeeNeutralSuffix';
    } else if (!out.endsWith(_coffeeNeutralSuffix)) {
      out = '$out\n\n$_coffeeNeutralSuffix';
    }
    return out;
  }

  static String postProcessSymbolicText(String input) {
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.isEmpty) out = 'Yorum\n\nSemboller sembolik çağrışımlar veriyor.';

    final lines = out.split('\n');
    final kept = <String>[];
    for (final line in lines) {
      final t = line.trimRight();
      if (t.trim().isEmpty) {
        kept.add('');
        continue;
      }
      if (_shouldDropCoffeeSentence(t)) continue;
      kept.add(t);
    }
    out = kept.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    if (!_containsCoffeeDisclaimer(out) || !out.endsWith(_coffeeNeutralSuffix)) {
      out = '$out\n\n$_coffeeNeutralSuffix'.trim();
    }
    return out;
  }

  static String _titleForTypeTr(String type) {
    switch (type) {
      case 'dream':
        return 'Rüya Tabiri';
      case 'palm':
        return 'El Çizgisi Yorumu';
      case 'astro':
        return 'Astroloji';
      case 'tarot':
        return 'Tarot';
      case 'coffee':
        return 'Kahve Yorumu';
      default:
        return 'Yorum';
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

  static String _weekdayTr(DateTime now) {
    const names = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return names[((now.weekday - 1) % 7).clamp(0, 6)];
  }

  static String _formatCoffeeReading({
    required String raw,
    required String userName,
    required String locale,
    String? prevIntroSig,
    int attempt = 0,
  }) {
    var cleaned = postProcessCoffeeText(raw);
    cleaned = _ensureCoffeeOutro(cleaned, userName: userName);
    // Zaten doğru format ise bozma
    if (cleaned.startsWith('Kahve Yorumu') &&
        cleaned.contains('Bugünün Mini Önerileri:') &&
        cleaned.endsWith(_coffeeNeutralSuffix) &&
        cleaned.length >= _coffeeMinChars &&
        cleaned.length <= _coffeeMaxChars) {
      return cleaned;
    }

    final now = DateTime.now();
    final dow = locale.startsWith('tr') ? _weekdayTr(now) : now.weekday.toString();
    final rnd = Random(now.millisecondsSinceEpoch + attempt * 9973);

    final openings = <String>[
      'fincanın genel havası sakin ama bir o kadar da canlı bir izlenim veriyor; sanki iç dünyanda küçük bir toparlanma isteği var. Bugünün ritmi $dow gibi: yumuşak ama kararlı.',
      'fincanın kenarlarında ince akışlar var; bu da düşüncelerin bir araya gelmeye çalıştığı hissini veriyor. $dow ritmi, acele etmeden netleşmeyi çağrıştırıyor.',
      'fincandaki izler dalga dalga; duyguların birikip sonra yavaşça çözüldüğü gibi. $dow enerjisi, küçük ama bilinçli bir odak değişimini destekliyor.',
      'fincanın tabanında yoğunluk, ağız kısmında açıklık var; sanki zihnin dolu ama niyetin sadeleşmek istiyor. $dow ritmi, sakin bir toparlanmayı işaret ediyor gibi.',
    ];
    var opening = openings[rnd.nextInt(openings.length)];
    final candidateIntro = 'Kahve Yorumu\n\n$userName, $opening';
    if (prevIntroSig != null && prevIntroSig.trim().isNotEmpty) {
      if (_sigFromIntro(candidateIntro) == prevIntroSig.trim().toLowerCase()) {
        opening = openings[(rnd.nextInt(openings.length - 1) + 1) % openings.length];
      }
    }

    final shapes = [
      ['kuş', 'haberleşme ve içsel ferahlama'],
      ['yol', 'odak değişimi ve kararları sadeleştirme'],
      ['anahtar', 'farkındalık ve küçük bir çözüm kapısı'],
      ['halka', 'sınır/bağ ve tamamlanma hissi'],
      ['dağ', 'sabır ve iç güç'],
      ['dalga', 'duygu akışı ve ritim'],
      ['göz', 'dikkat ve sezgisel uyanıklık'],
      ['kalp', 'yumuşaklık ve yakınlık ihtiyacı'],
    ]..shuffle(rnd);
    final a = shapes[0], b = shapes[1], c = shapes[2];

    final obs = [
      'Kenar tarafında "${a[0]}" gibi bir iz seçiliyor; bu, ${a[1]} temasını nazikçe hatırlatıyor.',
      'Orta kısımda "${b[0]}" hissi veren bir çizgi var; ${b[1]} gibi bir çağrışım bırakıyor.',
      'Tabana yakın yerde "${c[0]}" benzeri bir yoğunluk göze çarpıyor; ${c[1]} sanki öne çıkıyor.',
      'Bu şekillerin hepsi bir arada, zihninin “çok”tan “öz”e inmeye çalıştığı izlenimini veriyor.',
    ];

    final theme = [
      'Günün teması bence “netleştirme”: bir şeyi büyütmeden önce önce çerçevesini çizmek.',
      'İletişim tarafında “az ama öz” yaklaşımı iyi gelebilir; uzun açıklamalar yerine tek cümlelik niyet.',
      'Duygusal olarak da “yumuşak sınır” fikri var; hem yakın kalıp hem de kendini korumak gibi.',
    ];

    final miniSocial = [
      'Bugün bir kişiye kısa ve içten bir mesaj at; “seni düşündüm” gibi küçük bir temas yeterli.',
      'Bir konuşmayı uzatmadan, tek bir net soru sorarak iletişimi sadeleştir.',
      'Sosyal enerjini artırmak için kısa bir yürüyüşe birini dahil etmeyi dene.',
    ];
    final miniInner = [
      '2 dakika gözlerini kapatıp “şu an bende ne ağır?” diye sor; çıkan tek kelimeyi not al.',
      'Günün sonunda 3 cümlelik bir kapanış yaz: ne hissettim, ne öğrendim, neyi bırakıyorum.',
      'Niyetini tek cümleye indir ve bunu gün içinde iki kez hatırla.',
    ];

    final ctas = [
      'Fincanın sonuna geliyorken, küçük bir detay daha kalmış gibi… Yarın tekrar baktığında izler daha netleşebilir.',
      'Kahve yorumunun sonuna geliyorken, sanki fincan “ikinci bakış” istiyor… İstersen aynı kahveyi 2. kez yorumlayalım; bazen ikinci bakış daha çok şey söylüyor.',
      'Bu yorum burada kapanıyor ama fincandaki izler değişir; yeni bir fincanla tekrar geldiğinde kaldığımız yerden devam ederiz.',
    ];

    final paragraphs = <String>[
      'Kahve Yorumu\n\n$userName, $opening',
      obs.join(' '),
      theme.join(' '),
      'Bugünün Mini Önerileri:\n- ${miniSocial[rnd.nextInt(miniSocial.length)]}\n- ${miniInner[rnd.nextInt(miniInner.length)]}',
      '${ctas[rnd.nextInt(ctas.length)]}\n\n$_coffeeNeutralSuffix',
    ];

    var out = paragraphs.join('\n\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    // Uzunluk hedefi: kısa kalırsa gözlem cümlelerini genişlet
    if (out.length < _coffeeMinChars) {
      final extra = [
        'Fincanda bazı boşlukların temiz kalması da önemli; sanki zihnin “yer aç” diyor ve bu, daha rahat nefes alma hissi getiriyor.',
        'İzlerin birbirine yaklaşması, aynı konuya tekrar dönme eğilimini çağrıştırıyor; ama bu kez daha yumuşak bir bakışla.',
        'Bu satırlar bir kehanet değil; sadece fincandaki şekillerin sembolik çağrışımları olarak okunabilir.',
      ];
      out = [
        paragraphs[0],
        '${paragraphs[1]} ${extra.join(' ')}',
        paragraphs[2],
        paragraphs[3],
        paragraphs[4],
      ].join('\n\n').trim();
    }

    // Çok uzunsa, tema paragrafını kısalt
    if (out.length > _coffeeMaxChars) {
      out = [
        paragraphs[0],
        paragraphs[1],
        'Günün teması: netleştirme ve sadeleşme hissi.',
        paragraphs[3],
        paragraphs[4],
      ].join('\n\n').trim();
    }

    // Son güvenlik
    out = postProcessCoffeeText(out);
    out = _ensureCoffeeOutro(out, userName: userName);
    out = _clampCoffeeWithOutro(out, userName: userName);
    out = postProcessCoffeeText(out);
    // Başlık zorunlu
    if (!out.startsWith('Kahve Yorumu')) {
      out = 'Kahve Yorumu\n\n$out';
    }
    // İsim ilk paragrafta zorunlu
    if (!out.split('\n\n').first.contains('$userName,')) {
      out = out.replaceFirst('Kahve Yorumu\n\n', 'Kahve Yorumu\n\n$userName, ');
    }
    return out;
  }

  static String _coffeeOutro(String userName) => [
        '$userName, bu fincanda söylenebilecekler şimdilik bu kadar…',
        'Ama hislerin hâlâ konuşuyor.',
        '',
        'Biraz zaman geçsin,',
        'içinden tekrar bakmak gelirse',
        'fincanını yeniden açabilirsin.',
        'Buradayız.',
      ].join('\n');

  static String _ensureCoffeeOutro(String input, {required String userName}) {
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.isEmpty) return out;

    // Remove disclaimer temporarily; we will append again after outro.
    var body = out;
    if (body.endsWith(_coffeeNeutralSuffix)) {
      body = body.substring(0, body.length - _coffeeNeutralSuffix.length).trimRight();
    }

    final marker = 'bu fincanda söylenebilecekler şimdilik bu kadar';
    if (!body.toLowerCase().contains(marker)) {
      body = '$body\n\n${_coffeeOutro(userName)}';
    }

    // If too short, pad slightly (still symbolic).
    if (body.length < _coffeeMinChars - 180) {
      body = '$body\n\nBu satırlar bir kehanet değil; fincandaki şekillerin sembolik çağrışımları olarak yorumlanabilir.';
    }

    return '$body\n\n$_coffeeNeutralSuffix'.trim();
  }

  static String _clampCoffeeWithOutro(String input, {required String userName}) {
    var out = input.replaceAll('\r\n', '\n').trim();
    if (out.length <= _coffeeMaxChars) return out;

    // Split into [bodyWithoutOutro] + [outro] + [disclaimer]
    final outro = _coffeeOutro(userName);
    final marker = 'bu fincanda söylenebilecekler şimdilik bu kadar';
    final idx = out.toLowerCase().lastIndexOf(marker);
    if (idx <= 0) {
      return _clampToRange(out, min: _coffeeMinChars, max: _coffeeMaxChars);
    }

    // Keep the ending block intact; trim earlier body to fit max.
    final endBlock = '\n\n$outro\n\n$_coffeeNeutralSuffix';
    final allowedBody = (_coffeeMaxChars - endBlock.length).clamp(200, _coffeeMaxChars);

    var body = out.substring(0, idx).trimRight();
    body = _clampToRange(body, min: 0, max: allowedBody);
    var rebuilt = '$body\n\n$outro\n\n$_coffeeNeutralSuffix'.trim();

    if (rebuilt.length < _coffeeMinChars) {
      // If clamping made it too short, keep a bit more of the original body if possible.
      rebuilt = _clampToRange(out, min: _coffeeMinChars, max: _coffeeMaxChars);
    }
    return rebuilt;
  }

  static bool _shouldDropCoffeeSentence(String sentence) {
    if (_coffeeBannedWordRe.hasMatch(sentence)) return true;
    if (_coffeeDateRe.hasMatch(sentence)) return true;
    if (_coffeeMonthRe.hasMatch(sentence)) return true;
    if (_coffeeTimeRe.hasMatch(sentence)) return true;
    if (_coffeeRelativeRe.hasMatch(sentence)) return true;
    return false;
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
      'app': 'MystiQ',
    };
  }
}
