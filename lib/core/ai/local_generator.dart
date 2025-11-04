import 'dart:math';
import '../../features/profile/user_profile.dart';

// Clean, ASCII-safe local generator used as a fallback when remote AI fails
class LocalAIGenerator {
  static String generate({
    required String type, // coffee|tarot|palm|astro|dream|live_chat
    required UserProfile profile,
    int? seed,
    Map<String, dynamic>? extras,
    String locale = 'tr',
  }) {
    final rnd = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    final lang = (locale == 'ar') ? 'en' : locale; // keep Arabic readable by falling back to English
    final dow = _weekdayName(locale: lang, weekday: DateTime.now().weekday);

    final Map<String, dynamic> i18n = (extras?['i18n'] is Map)
        ? Map<String, dynamic>.from(extras!['i18n'] as Map)
        : <String, dynamic>{};
    String i(String key, String fallback) {
      final v = i18n[key];
      return (v is String && v.trim().isNotEmpty) ? v : fallback;
    }

    final String name = profile.name.isEmpty
        ? ({
            'tr': i('ai.dear_soul', 'Sevgili ruh'),
            'en': i('ai.dear_soul', 'Dear soul'),
            'es': i('ai.dear_soul', 'Alma querida'),
          }[lang] ?? i('ai.dear_soul', 'Dear soul'))
        : profile.name;

    if (type == 'live_chat') {
      final tone = (extras?['tone'] ?? 'friendly').toString();
      final length = (extras?['length'] ?? 'medium').toString();
      return _liveChat(lang, name, profile.zodiac, tone, length, dow, rnd, i18n);
    }

    final isPremium = (extras?['premium'] == true);

    // Template-first fallback
    final tplKey = 'ai.template.$type';
    final tpl = i18n[tplKey];
    String out;
    if (tpl is String && tpl.trim().isNotEmpty) {
      out = _fillTemplate(tpl, lang, name, dow, profile, extras);
    } else {
      switch (type) {
        case 'coffee':
          out = _coffee(lang, name, dow, rnd, extras, i18n);
          break;
        case 'tarot':
          final cards = (extras?['cards'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
          out = _tarot(lang, name, cards, dow, rnd);
          break;
        case 'palm':
          out = _palm(lang, name, dow, rnd);
          break;
        case 'dream':
          final text = (extras?['text'] ?? '').toString();
          out = _dream(lang, name, text, dow, rnd);
          break;
        case 'astro':
          out = _astro(lang, name, profile.zodiac, dow, rnd);
          break;
        default:
          out = _generic(lang, name, dow, rnd);
      }
    }

    // Style modifiers
    if (type == 'dream') {
      final style = (extras?['style'] ?? '').toString();
      out = _applyDreamStyle(lang, out, style);
    }
    if (type == 'astro') {
      final style = (extras?['style'] ?? '').toString();
      out = _applyAstroStyle(lang, out, style);
    }
    if (type == 'coffee') {
      final style = (extras?['style'] ?? '').toString();
      out = _applyCoffeeStyle(lang, out, style);
    }
    if (type == 'tarot') {
      final style = (extras?['style'] ?? '').toString();
      out = _applyTarotStyle(lang, out, style);
    }
    if (type == 'palm') {
      final style = (extras?['style'] ?? '').toString();
      out = _applyPalmStyle(lang, out, style);
    }
    if (isPremium) {
      out = _appendPremiumTyped(type, lang, out, i18n);
    }
    return out;
  }

  static String _fillTemplate(String tpl, String locale, String name, String dow, UserProfile profile, Map<String, dynamic>? extras) {
    var out = tpl;
    out = out.replaceAll('{name}', name);
    out = out.replaceAll('{dow}', dow);
    out = out.replaceAll('{zodiac}', profile.zodiac.isEmpty ? ({'tr': 'burcun', 'es': 'tu signo', 'en': 'your sign'}[locale] ?? 'your sign') : profile.zodiac);
    if (extras != null) {
      if (extras['cards'] is List) {
        final cards = (extras['cards'] as List).map((e) => '$e').toList();
        out = out.replaceAll('{cards}', cards.join(', '));
      }
      if (extras['text'] != null) {
        out = out.replaceAll('{text}', '${extras['text']}');
      }
      if (extras['topic'] != null) {
        final raw = '${extras['topic']}';
        String label;
        switch (locale) {
          case 'tr':
            switch (raw) {
              case 'love': label = 'Ask'; break;
              case 'work': label = 'Is'; break;
              case 'money': label = 'Para'; break;
              case 'health': label = 'Saglik'; break;
              default: label = 'Genel';
            }
            break;
          case 'es':
            switch (raw) {
              case 'love': label = 'Amor'; break;
              case 'work': label = 'Trabajo'; break;
              case 'money': label = 'Dinero'; break;
              case 'health': label = 'Salud'; break;
              default: label = 'General';
            }
            break;
          default:
            switch (raw) {
              case 'love': label = 'Love'; break;
              case 'work': label = 'Work'; break;
              case 'money': label = 'Money'; break;
              case 'health': label = 'Health'; break;
              default: label = 'General';
            }
        }
        out = out.replaceAll('{topic}', label);
      }
    }
    return out;
  }

  // Legacy minimal generator used rarely
  static String _coffeeLegacy(String locale, String name, String dow, Random rnd) {
    switch (locale) {
      case 'tr':
        return '$name, fincandaki izler $dow ritmiyle uyumlu. Kucuk ve somut bir adim bugun iyi gelir.';
      case 'es':
        return '$name, las huellas en tu taza reflejan el ritmo de $dow. Un paso pequeno y concreto viene bien.';
      default:
        return '$name, the cup patterns mirror the flow of $dow. A small, concrete step fits the day.';
    }
  }

  // New topic-aware coffee generator (fallback when no template is provided)
  static String _coffee(String locale, String name, String dow, Random rnd, Map<String, dynamic>? extras, Map<String, dynamic> i18n) {
    String i(String key, String fallback) {
      final v = i18n[key];
      return (v is String && v.trim().isNotEmpty) ? v : fallback;
    }
    final raw = (extras?['topic'] ?? 'general').toString();
    String topicLabel() {
      switch (locale) {
        case 'tr':
          switch (raw) {
            case 'love': return 'Ask';
            case 'work': return 'Is';
            case 'money': return 'Para';
            case 'health': return 'Saglik';
            default: return 'Genel';
          }
        case 'es':
          switch (raw) {
            case 'love': return 'Amor';
            case 'work': return 'Trabajo';
            case 'money': return 'Dinero';
            case 'health': return 'Salud';
            default: return 'General';
          }
        default:
          switch (raw) {
            case 'love': return 'Love';
            case 'work': return 'Work';
            case 'money': return 'Money';
            case 'health': return 'Health';
            default: return 'General';
          }
      }
    }
    final t = topicLabel();

    if (locale == 'tr') {
      final intro = i('coffee.intro.tr', '$name, fincan izleri $dow ritmiyle uyumlu. Konu: $t.');
      final rim = i('coffee.rim.tr', 'Kenar cizgileri tekrar eden bir oruntu gosteriyor; niyetini sade tut.');
      final base = i('coffee.base.tr', 'Tabanda yogunluk: bugun tek ve somut bir adimi tamamlamak iyi gelir.');
      final symbol = i('coffee.symbol.tr', 'Silik bir yay: esneklik ve nazik bir donus ivme katar.');
      final action = i('coffee.action.tr', 'Aksam 3 cumlelik kapanis yaz.');
      final actionTopic = i('coffee.topic.tr', 'Odak');
      final closing = i('coffee.closing.tr', 'Not: Eglence amaclidir; sezgini dinle.');
      return [intro, rim, base, symbol, '$actionTopic: $action', closing].join('\n\n');
    }

    // EN (default)
    final introEn = i('coffee.intro.en', '$name, the cup traces align with the rhythm of $dow. Topic: $t.');
    final rimEn = i('coffee.rim.en', 'Repeating arcs suggest a pattern; simplify your intention to unlock flow.');
    final baseEn = i('coffee.base.en', 'Sediment density hints that finishing one small task will lift the weight.');
    final symbolEn = i('coffee.symbol.en', 'Short clusters invite a single-focus block to gather energy.');
    final closingEn = i('coffee.closing.en', 'Note: For entertainment; combine insights with your own judgment.');
    return [introEn, rimEn, baseEn, symbolEn, closingEn].join('\n\n');
  }

  static String _tarot(String locale, String name, List<String>? cards, String dow, Random rnd) {
    final list = (cards != null && cards.isNotEmpty) ? ' ' + cards.join(', ') : '';
    switch (locale) {
      case 'tr':
        return '$name, kartlar$list netlik ve odak oneriyor. Bir seyi tamamlamak ivme katar.';
      case 'es':
        return '$name, las cartas$list sugieren claridad y enfoque. Completar una cosa ayuda.';
      default:
        return '$name, the cards$list suggest clarity and focus. Completing one thing helps.';
    }
  }

  static String _palm(String locale, String name, String dow, Random rnd) {
    switch (locale) {
      case 'tr':
        return '$name, avuc cizgilerin denge ve toparlanma gosteriyor. Yurekte sefkat, zihinde basit hedef.';
      case 'es':
        return '$name, las lineas de tu palma indican equilibrio y recuperacion. Compasion y metas simples.';
      default:
        return '$name, your palm lines indicate balance and recovery. Compassion in heart, simple goals in mind.';
    }
  }

  static String _dream(String locale, String name, String text, String dow, Random rnd) {
    final bullet = text.trim().isNotEmpty ? '\n- ' + text.trim() : '';
    switch (locale) {
      case 'tr':
        return '$name, ruya imgelerin duygusal bir arinmaya davet ediyor.$bullet\nAksam kisa bir rituel gune iyi gelir.';
      case 'es':
        return '$name, las imagenes del sueno invitan a una limpieza emocional.$bullet';
      default:
        return '$name, your dream images invite emotional cleansing.$bullet\nA small evening ritual helps end the day well.';
    }
  }

  static String _astro(String locale, String name, String zodiac, String dow, Random rnd) {
    final z = zodiac.isEmpty ? ({'tr': 'burcun', 'es': 'tu signo', 'en': 'your sign'}[locale] ?? 'your sign') : zodiac;
    switch (locale) {
      case 'tr':
        return '$name, bugun $z icin nazik ama net bir yon ortaya cikiyor. Kucuk bir seyi tamamlamak iyi gelir.';
      case 'es':
        return '$name, hoy surge una direccion suave pero clara para $z. Completar algo pequeno ayuda.';
      default:
        return '$name, a gentle but clear direction may emerge for $z today. Completing one small thing helps.';
    }
  }

  static String _generic(String locale, String name, String dow, Random rnd) {
    switch (locale) {
      case 'tr':
        return '$name, $dow akisi ile uyumlu kucuk ve somut adimlar sec.';
      case 'es':
        return '$name, elige pasos pequenos y concretos acordes al flujo de $dow.';
      default:
        return '$name, choose small, concrete steps aligned with the flow of $dow.';
    }
  }

  static String _applyDreamStyle(String locale, String base, String style) {
    if (style == 'poetic') {
      final add = ({
        'tr': '\n\nGecenin sessizliginde sembolun yavasca beliriyor; her satir icindeki sese yaklasir.',
        'es': '\n\nEn el silencio de la noche tu simbolo aparece; cada linea te acerca a tu voz interior.',
        'en': '\n\nIn the night silence your symbol appears; each line draws you closer to your inner voice.',
      }[locale] ?? '\n\nIn the night silence your symbol appears; each line draws you closer to your inner voice.');
      return base.trim() + add;
    }
    // practical (default): add bullet points
    final add = ({
      'tr': ['\n- Gun icinde sembolune iki kez dikkat et', '- Duyguyu tek kelime ile adlandir', '- Aksam 3 cumlelik kisa bir ozet yaz'],
      'es': ['\n- Observa tu simbolo dos veces', '- Nombra la emocion en una palabra', '- Escribe un cierre de 3 frases al anochecer'],
      'en': ['\n- Notice your symbol twice', '- Name the feeling in one word', '- Write a 3-sentence evening review'],
    }[locale] ?? ['\n- Notice your symbol twice','- Name the feeling in one word','- Write a 3-sentence evening review']);
    return base.trim() + add.join('\n');
  }

  static String _applyAstroStyle(String locale, String base, String style) {
    if (style == 'spiritual') {
      final add = ({
        'tr': '\n\nBugun yildizlar nazik bir ritim fisildiyor; niyetini sakin bir cumleyle netlestir ve basla.',
        'es': '\n\nHoy las estrellas susurran un ritmo suave; aclara tu intencion en una frase y empieza asi.',
        'en': '\n\nToday the stars whisper a gentle rhythm; clarify your intention in one sentence and begin.',
      }[locale] ?? '\n\nToday the stars whisper a gentle rhythm; clarify your intention in one sentence and begin.');
      return base.trim() + add;
    }
    // practical
    final add = ({
      'tr': ['\n- 15-20 dk tek odak planla', '- Oglen 5 dk yuruyus ekle', '- Aksam 3 cumlelik kapanis yaz'],
      'es': ['\n- Bloque de 15-20 min de enfoque', '- Anade caminata de 5 min al mediodia', '- Cierre de 3 frases por la noche'],
      'en': ['\n- Plan a 15-20 min single-focus block', '- Add a 5-min walk at noon', '- 3-sentence evening review'],
    }[locale] ?? ['\n- Plan a 15-20 min single-focus block','- Add a 5-min walk at noon','- 3-sentence evening review']);
    return base.trim() + add.join('\n');
  }

  static String _applyCoffeeStyle(String locale, String base, String style) {
    if (style == 'spiritual') {
      final add = ({
        'tr': '\n\nFincanin sessizliginde niyetin berraklasiyor; kokuyu ve sicakligi dinle, bir cumlelik niyet yaz.',
        'en': "\n\nIn the cup's silence your intention clears; listen to aroma and warmth, write one clear line.",
      }[locale] ?? "\n\nIn the cup's silence your intention clears; write one clear line.");
      return base.trim() + add;
    }
    if (style == 'analytical') {
      final add = ({
        'tr': ['\n- Kenar izleri: tekrar eden sekli bul', '- Taban: yogunluk/bosluk dengesi', '- Sonuc: tek net cumle yaz'],
        'en': ['\n- Rim: find repeating trace', '- Base: density vs. void', '- Outcome: one clear sentence'],
      }[locale] ?? ['\n- Rim: find repeating trace','- Base: density vs. void','- Outcome: one clear sentence']);
      return base.trim() + add.join('\n');
    }
    final add = ({
      'tr': ['\n- 10-15 dk tek odak ayir', '- Birine nazik bir mesaj gonder', '- Aksam 3 cumlelik kapanis yaz'],
      'en': ['\n- 10-15 min single-focus', '- Send a kind message', '- 3-sentence evening review'],
    }[locale] ?? ['\n- 10-15 min single-focus','- Send a kind message','- 3-sentence evening review']);
    return base.trim() + add.join('\n');
  }

  static String _applyTarotStyle(String locale, String base, String style) {
    if (style == 'spiritual') {
      final add = ({
        'tr': '\n\nKartlarin fisiltisi: niyetini bir cumlede netlestir ve tek adim at.',
        'en': '\n\nWhisper of the spread: clarify a one-line intention and take one step.',
      }[locale] ?? '\n\nClarify a one-line intention and take one step.');
      return base.trim() + add;
    }
    if (style == 'analytical') {
      final add = ({
        'tr': ['\n- Gecmis: ana tema', '- Simdi: odak ve risk', '- Gelecek: tek mikro-adim'],
        'en': ['\n- Past: main theme', '- Present: focus & risk', '- Future: one micro-step'],
      }[locale] ?? ['\n- Past: main theme','- Present: focus & risk','- Future: one micro-step']);
      return base.trim() + add.join('\n');
    }
    final add = ({
      'tr': ['\n- Bir kart mesajini tek cumle yaz', '- 20 dk tek odak planla', '- 3 cumlelik aksam geri-bakisi'],
      'en': ['\n- One-sentence card message', '- Plan 20 min single-focus', '- 3-sentence evening review'],
    }[locale] ?? ['\n- One-sentence card message','- Plan 20 min single-focus','- 3-sentence evening review']);
    return base.trim() + add.join('\n');
  }

  static String _applyPalmStyle(String locale, String base, String style) {
    if (style == 'spiritual') {
      final add = ({
        'tr': '\n\nAvucun bir hafiza gibi: kalp ve akil cizgisi bugun nazik netlikte bulusuyor.',
        'en': "\n\nYour palm like a memory: heart and head lines echo gentle clarity today.",
      }[locale] ?? '\n\nGentle clarity for heart and head lines today.');
      return base.trim() + add;
    }
    if (style == 'analytical') {
      final add = ({
        'tr': ['\n- Kalp cizgisi: iletisim ornegi', '- Bas cizgisi: plan ve sure', '- Basparmak: gunun tek karari'],
        'en': ["\n- Heart line: comms example", '- Head line: plan & duration', "- Thumb: today's single decision"],
      }[locale] ?? ["\n- Heart line: comms example",'- Head line: plan & duration',"- Thumb: today's single decision"]);
      return base.trim() + add.join('\n');
    }
    final add = ({
      'tr': ['\n- 20 dk tek-odak sprint', '- Nazik bir mesaj gonder', '- 3 cumlelik aksam kapanisi'],
      'en': ['\n- 20 min single-focus', '- Send a kind message', '- 3-sentence evening close'],
    }[locale] ?? ['\n- 20 min single-focus','- Send a kind message','- 3-sentence evening close']);
    return base.trim() + add.join('\n');
  }

  static String _appendPremiumTyped(String type, String locale, String base, Map<String, dynamic> i18n) {
    String pick(String k, String fb) {
      final v = i18n[k];
      return (v is String && v.trim().isNotEmpty) ? v : fb;
    }
    final header = pick('premium.header', ({
      'tr': 'Derinlestirme',
      'es': 'Profundizacion',
      'en': 'Deepening',
    }[locale] ?? 'Deepening'));

    String sectionTitle() {
      switch (type) {
        case 'coffee': return pick('premium.coffee.section', 'Beyond the Cup');
        case 'tarot': return pick('premium.tarot.section', 'Roadmap');
        case 'palm': return pick('premium.palm.section', 'Hand Analysis');
        case 'dream': return pick('premium.dream.section', 'Symbol Journal');
        case 'astro': return pick('premium.astro.section', 'Daily Focus');
        default: return pick('premium.default.section', 'Deepening');
      }
    }

    final closing = pick('premium.closing', ({
      'tr': 'Bugun tek somut adim sec ve uygula.',
      'es': 'Elige un paso concreto hoy y aplicalo.',
      'en': 'Choose one concrete step today and apply it.',
    }[locale] ?? 'Choose one concrete step today and apply it.'));

    return [
      base.trim(),
      '',
      header,
      sectionTitle(),
      closing,
    ].join('\n');
  }

  static String _appendCoffeeOutro(String locale, String base, String name) {
    String tr = '($name), falinin sonlarina gelirken fincanindaki sirlar sessizlesti...\n'
        'Ama enerjin hala evrenle konusuyor.\n'
        'Kaderin bir sonraki mesaji icin yeniden bir kahve pisir, niyetini dile ve fincanini hazirla.\n\n'
        'Unutma, her fincan bir anahtar...\n'
        'Ve bir sonraki kapiyi sadece MystiQ\'te acabilirsin.';
    String en = '($name), as the cup grows quiet, its secrets settle...\n'
        'Yet your energy is still in dialogue with the universe.\n'
        'For the next message of fate, brew another coffee, set your intention, and prepare your cup.\n\n'
        'Remember, every cup is a key...\n'
        'And the next door opens only on MystiQ.';
    String es = '($name), hacia el final la taza se aquieta y sus secretos reposan...\n'
        'Pero tu energia sigue conversando con el universo.\n'
        'Para el proximo mensaje del destino, prepara otro cafe, formula tu intencion y alista tu taza.\n\n'
        'Recuerda: cada taza es una llave...\n'
        'Y la proxima puerta se abre solo en MystiQ.';
    final pick = ({'tr': tr, 'es': es, 'en': en}[locale]) ?? tr;
    return base.trim() + '\n\n' + pick;
  }

  static String _liveChat(String locale, String name, String zodiac, String tone, String length, String dow, Random rnd, Map<String, dynamic> i18n) {
    String i(String key, String fb) {
      final v = i18n[key];
      return (v is String && v.trim().isNotEmpty) ? v : fb;
    }

    final opener = i('live.opener', ({
      'tr': '$name, niyetin $dow ile uyumlu. Kucuk ve somut bir adim simdi iyi olur.',
      'es': '$name, tu intencion fluye con $dow. Un paso pequeno y concreto viene bien.',
      'en': '$name, your intention aligns with the flow of $dow. A small, concrete step fits now.',
    }[locale] ?? 'Your intention aligns with the day.'))
        .replaceAll('{name}', name)
        .replaceAll('{dow}', dow);

    List<String> tipsFromI18n() {
      final out = <String>[];
      for (var k = 0; k < 6; k++) {
        final v = i18n['live.tip.$k'];
        if (v is String && v.trim().isNotEmpty) out.add(v);
      }
      return out;
    }
    final fallback = ({
      'tr': [
        "3 derin nefes al ve 'Birakiyorum' diyerek ver.",
        'Konunu tek cumleyle yaz ve telefonuna not et.',
        '10 dakikalik tek-odak zamani ayir; bildirimleri kapat.',
      ],
      'es': [
        "Respira 3 veces y suelta diciendo 'Suelto'.",
        'Redacta tu tema en una frase y anotalo.',
        'Reserva 10 minutos de enfoque unico; silencia notificaciones.',
      ],
      'en': [
        "Take 3 deep breaths and exhale saying 'I release'.",
        'Write your topic in one sentence and note it.',
        'Block a 10-minute single-focus slot; silence notifications.',
      ]
    }[locale] ?? [
      'Take a breath and center yourself.',
      'Write one clear sentence about your question.',
    ]);

    final mergedTips = tipsFromI18n().isNotEmpty ? tipsFromI18n() : fallback;
    final count = length == 'short' ? 1 : 2;
    final sb = StringBuffer()
      ..writeln(opener)
      ..writeln()
      ..writeln(i('live.tips_header', ({'tr': 'Oneriler:', 'es': 'Sugerencias:', 'en': 'Tips:'}[locale] ?? 'Tips:')));
    for (var i0 = 0; i0 < count; i0++) {
      sb.writeln('- ${mergedTips[rnd.nextInt(mergedTips.length)]}');
    }
    if (zodiac.isNotEmpty) {
      final elem = _inferElementTr(zodiac);
      if (elem.isNotEmpty) {
        final astro = i('live.astro_note', ({
          'tr': 'Astro notu: {elem} elementi bugun sezgini destekliyor.',
          'es': 'Nota astro: el elemento {elem} apoya tu intuicion hoy.',
          'en': 'Astro note: The {elem} element supports your intuition today.',
        }[locale] ?? 'Astro note: intuition supported.'));
        sb..writeln()..writeln(astro.replaceAll('{elem}', elem));
      }
    }
    sb..writeln()..writeln(i('live.follow_up', ({
      'tr': 'Asil sorunu tek cumleyle yazar misin?',
      'es': 'Puedes compartir tu pregunta central en una frase?',
      'en': 'Can you share your core question in one sentence?',
    }[locale] ?? 'Share your core question in one sentence.')));

    return sb.toString();
  }
}

String _weekdayName({required String locale, required int weekday}) {
  // 1..7 Monday..Sunday per Dart DateTime
  final idx = ((weekday - 1) % 7).clamp(0, 6);
  final tr = ['Pazartesi','Sali','Carsamba','Persembe','Cuma','Cumartesi','Pazar'];
  final es = ['lunes','martes','miercoles','jueves','viernes','sabado','domingo'];
  final en = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  switch (locale) {
    case 'tr': return tr[idx];
    case 'es': return es[idx];
    default: return en[idx];
  }
}

String _inferElementTr(String zodiac) {
  final z = zodiac.toLowerCase();
  const fire = ['koc', 'aslan', 'yay'];
  const earth = ['boga', 'basak', 'oglak'];
  const air = ['ikizler', 'terazi', 'kova'];
  const water = ['yengec', 'akrep', 'balik'];
  if (fire.any((e) => z.contains(e))) return 'Ateş';
  if (earth.any((e) => z.contains(e))) return 'Toprak';
  if (air.any((e) => z.contains(e))) return 'Hava';
  if (water.any((e) => z.contains(e))) return 'Su';
  return '';
}
