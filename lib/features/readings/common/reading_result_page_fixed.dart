import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import '../../../core/ai/local_generator.dart';
import '../../../core/ai/ai_service.dart';
import '../../profile/profile_controller.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../core/entitlements/entitlements_controller.dart';
import '../../../core/readings/pending_readings_service.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../common/widgets/sharp_image.dart';
import '../tarot/tarot_deck_fixed.dart';

class ReadingResultPage extends StatefulWidget {
  final String type; // coffee | tarot | palm | dream | astro
  final String? providedText; // from history
  final Map<String, dynamic>? requestExtras; // imagePath, text, cardIndices, delay, unlockMethod
  const ReadingResultPage({super.key, required this.type, this.providedText, this.requestExtras});

  @override
  State<ReadingResultPage> createState() => _ReadingResultPageState();
}

class _ReadingResultPageState extends State<ReadingResultPage> {
  String text = '';
  bool _saved = false;
  bool _placeholderProvided = false;
  StreamSubscription<String>? _sub;
  bool _streaming = false;
  bool _cancelled = false;
  Timer? _streamGuard;
  // Countdown for scheduled readiness (e.g., tarot 10/5 dk)
  Timer? _countdown;
  DateTime? _readyAt;
  int? _remainingSeconds;
  bool _countdownDone = false;
  bool _doneSnackShown = false;
  bool _deferGenerate = false;
  bool _didNormalizeProvided = false; // normalize providedText after context becomes available
  bool _speedupUsed = false;
  String? _pendingId; // for updating scheduled ETA

  @override
  void initState() {
    super.initState();
    _initCountdownFromExtras();
    try { _pendingId = (widget.requestExtras?['pendingId'] as String?); } catch (_) {}
    if (widget.providedText != null) {
      text = widget.providedText!;
      _placeholderProvided = _looksLikePlaceholder(text);
      _saved = !_placeholderProvided;
      if (_placeholderProvided && (widget.requestExtras == null || (widget.requestExtras?.isEmpty ?? true))) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndSave());
      }
    } else {
      _streaming = true;
      // ignore: unawaited_futures
      final e = widget.requestExtras ?? const <String, dynamic>{};
      final noStream = e['noStream'] == true;
      _deferGenerate = e['generateAtReady'] == true;
      if (noStream && !_deferGenerate) {
        _generateAndSave();
      } else if (!noStream) {
        _streamAndSave();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Localizations/AppLocalizations.of(context) should not be used in initState.
    // Normalize any providedText here when context is ready.
    if (!_didNormalizeProvided && widget.providedText != null && text.isNotEmpty) {
      try {
        if (text.trim().length < 1200) {
          text = _ensureMinLength(context, widget.type, text);
        }
      } catch (_) {}
      _didNormalizeProvided = true;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _streamGuard?.cancel();
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _initCountdownFromExtras() async {
    try {
      final e = widget.requestExtras ?? const <String, dynamic>{};
      DateTime? target;
      if (e['readyAt'] is String) {
        target = DateTime.tryParse(e['readyAt'] as String);
      }
      if (target == null && e['etaSeconds'] is int) {
        final s = (e['etaSeconds'] as int);
        if (s > 0) target = DateTime.now().add(Duration(seconds: s));
      }
      // If we have a pendingId, prefer the latest value from storage (handles speedup after re-entry)
      try {
        final pendingId = e['pendingId'] as String?;
        if (pendingId != null) {
          final it = await PendingReadingsService.getById(pendingId);
          final ra = DateTime.tryParse((it?['readyAt'] as String?) ?? '');
          if (ra != null && (target == null || ra.isAfter(DateTime.now()))) {
            target = ra;
          }
        }
      } catch (_) {}
      if (target == null) return;
      _readyAt = target;
      _tickCountdown();
      _countdown?.cancel();
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
    } catch (_) {}
  }

  void _tickCountdown() {
    if (_readyAt == null) return;
    final left = _readyAt!.difference(DateTime.now()).inSeconds;
    final rem = left > 0 ? left : 0;
    if (!mounted) return;
    setState(() {
      _remainingSeconds = rem;
      if (left <= 0) _countdownDone = true;
    });
    if (left <= 0) {
      try { _countdown?.cancel(); } catch (_) {}
      if (_deferGenerate && (!_saved) && (text.isEmpty || _placeholderProvided)) {
        _generateAndSave();
      }
      if (!_doneSnackShown && mounted) {
        _doneSnackShown = true;
        final loc = AppLocalizations.of(context);
        final msg = loc.t('reading.countdown.done') != 'reading.countdown.done'
            ? loc.t('reading.countdown.done')
            : 'Faliniz gecmis kutusuna yonlendirilmistir.';
        Future.microtask(() {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        });
      }
    }
  }

  Future<void> _generateAndSave() async {
    if (!mounted) return;
    try {
      final profile = context.read<ProfileController>().profile;
      final locale = Localizations.localeOf(context).languageCode;
      final extras = Map<String, dynamic>.from(widget.requestExtras ?? {});
      final ent = context.read<EntitlementsController>();
      final isPremium = ent.isPremium;
      extras['premium'] = isPremium;
      extras['length'] = isPremium ? 'long' : 'medium';
      extras['i18n'] = _premiumI18n(context);
      extras['energy'] = ent.energy;
      final forceLocal = extras['forceLocal'] == true;
      var generated = '';
      if (!forceLocal) {
        generated = await AiService.generate(
          type: widget.type,
          profile: profile,
          extras: extras,
          locale: locale,
        );
      } else {
        generated = LocalAIGenerator.generate(
          type: widget.type,
          profile: profile,
          extras: extras,
          locale: locale,
        );
      }
      generated = _withDailyHeader(context, widget.type, generated);
      generated = _appendPersonalOutro(widget.type, locale, profile.name, generated);
      if (generated.trim().length < 1600) {
        generated = _ensureMinLength(context, widget.type, generated);
      }
      if (!mounted) return;
      setState(() { text = generated; _streaming = false; });
      await _saveToHistory();
      await Analytics.log('reading_completed', {'type': widget.type});
    } catch (_) {
      // Local fallback
      final extras = Map<String, dynamic>.from(widget.requestExtras ?? {});
      final ent = context.read<EntitlementsController>();
      extras['premium'] = ent.isPremium;
      extras['length'] = ent.isPremium ? 'long' : 'medium';
      extras['i18n'] = _premiumI18n(context);
      extras['energy'] = ent.energy;
      var generated = LocalAIGenerator.generate(
        type: widget.type,
        profile: context.read<ProfileController>().profile,
        extras: extras,
        locale: Localizations.localeOf(context).languageCode,
      );
      generated = _withDailyHeader(context, widget.type, generated);
      generated = _appendPersonalOutro(widget.type, Localizations.localeOf(context).languageCode, context.read<ProfileController>().profile.name, generated);
      if (generated.trim().length < 1600) {
        generated = _ensureMinLength(context, widget.type, generated);
      }
      if (!mounted) return;
      setState(() { text = generated; _streaming = false; });
      await _saveToHistory();
    }
  }

  Future<void> _streamAndSave() async {
    if (!mounted) return;
    final profile = context.read<ProfileController>().profile;
    final locale = Localizations.localeOf(context).languageCode;
    final extras = Map<String, dynamic>.from(widget.requestExtras ?? {});
    if (extras['forceLocal'] == true) {
      // Skip streaming entirely
      await _generateAndSave();
      return;
    }
    final ent = context.read<EntitlementsController>();
    final isPremium = ent.isPremium;
    extras['premium'] = isPremium;
    extras['length'] = isPremium ? 'long' : 'medium';
    extras['i18n'] = _premiumI18n(context);
    extras['energy'] = ent.energy;
    _sub = AiService
        .streamGenerate(
            type: widget.type,
            profile: profile,
            extras: extras,
            locale: locale)
        .listen((chunk) {
      if (!mounted || _cancelled) return;
      setState(() => text = _withDailyHeader(context, widget.type, chunk));
    }, onDone: () async {
      if (!mounted || _cancelled) return;
      _streamGuard?.cancel();
      _streaming = false;
      // Append closing message once at end of stream
      final profile = context.read<ProfileController>().profile;
      final locale = Localizations.localeOf(context).languageCode;
      text = _appendPersonalOutro(widget.type, locale, profile.name, text);
      if (text.trim().length < 1600) {
        text = _ensureMinLength(context, widget.type, text);
      }
      await _saveToHistory();
      await Analytics.log('reading_completed', {'type': widget.type, 'stream': true});
      setState(() {});
    }, onError: (_) async {
      if (!mounted) return;
      _streamGuard?.cancel();
      _streaming = false;
      await _generateAndSave();
    });

    // Guard: if no chunk arrives within 6s, fall back to local generation
    _streamGuard?.cancel();
    _streamGuard = Timer(const Duration(seconds: 6), () async {
      if (!mounted || _cancelled) return;
      if (_streaming && (text.isEmpty)) {
        _sub?.cancel();
        _streaming = false;
        await _generateAndSave();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final hc = context.watch<HistoryController>();
    final entryId = _entryId(hc);
    final fav = entryId == null
        ? false
        : hc.items.firstWhere(
            (e) => e.id == entryId,
            orElse: () => HistoryEntry(id: '', type: '', title: '', text: '', createdAt: DateTime.now()),
          ).favorite;

    // Optional tarot cards row (always upright)
    final List<int>? cardIdxs = (widget.requestExtras?['cardIndices'] is List)
        ? (widget.requestExtras!['cardIndices'] as List)
            .map((e) => int.tryParse('$e') ?? -1)
            .where((e) => e >= 0)
            .toList()
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('reading.result.title')),
        actions: [
          if (entryId != null)
            IconButton(
              icon: Icon(fav ? Icons.star : Icons.star_border),
              onPressed: () => hc.toggleFavorite(entryId),
            ),
          IconButton(
            tooltip: AppLocalizations.of(context).t('action.copy'),
            icon: const Icon(Icons.copy),
            onPressed: text.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(loc.t('action.copied'))));
                    }
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleTr(context, widget.type), style: Theme.of(context).textTheme.titleLarge),
        if ((_remainingSeconds ?? 0) > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              _EtaBadge(seconds: _remainingSeconds!),
              const SizedBox(width: 8),
              if (!_speedupUsed)
                TextButton.icon(
                  icon: const Icon(Icons.rocket_launch, size: 16),
                  onPressed: () async {
                    final ok = await RewardedAds.show(context: context);
                    if (!ok || !mounted) return;
                    final now = DateTime.now();
                    final left = _remainingSeconds ?? 0;
                    final reduce = left > 240 ? 300 : (left ~/ 2).clamp(60, left);
                    final newReady = now.add(Duration(seconds: left - reduce));
                    setState(() { _readyAt = newReady; _remainingSeconds = (left - reduce); _speedupUsed = true; });
                    // Update pending schedule if known
                    try {
                      final id = _pendingId;
                      if (id != null) {
                        final locale = Localizations.localeOf(context).languageCode;
                        await PendingReadingsService.updateReadyAt(id: id, type: widget.type, readyAt: newReady, locale: locale);
                      }
                    } catch (_) {}
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).t('reading.speedup.thanks') != 'reading.speedup.thanks' ? AppLocalizations.of(context).t('reading.speedup.thanks') : 'Hızlandırıldı! Bekleme süresi kısaldı.')),
                    );
                  },
                  label: Text(AppLocalizations.of(context).t('reading.speedup.button') != 'reading.speedup.button' ? AppLocalizations.of(context).t('reading.speedup.button') : 'Hızlandır (reklam)'),
                ),
            ],
          ),
        ] else if (_countdownDone) ...[
          const SizedBox(height: 6),
          _DoneInfoBannerGold(),
        ],
        const SizedBox(height: 12),
        if (widget.type == 'tarot' && cardIdxs != null && cardIdxs.isNotEmpty)
          _TarotResultRow(indices: cardIdxs)
            else if (_streaming && text.isEmpty)
              const _ShimmerParagraph()
            else
              Expanded(child: SingleChildScrollView(child: Text(text))),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: text.isEmpty ? null : () => Share.share(text, subject: titleTr(context, widget.type)),
                  child: Text(loc.t('action.share')),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(loc.t('reading.again')),
                ),
                const Spacer(),
                if (_streaming)
                  TextButton(
                    onPressed: () async {
                      _cancelled = true;
                      _sub?.cancel();
                      setState(() => _streaming = false);
                      // Fallback: produce a local/remote result immediately
                      await _generateAndSave();
                    },
                    child: Text(loc.t('action.cancel')),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  String? _entryId(HistoryController hc) {
    try {
      final e = hc.items.firstWhere((e) => e.text == text && e.type == widget.type);
      return e.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToHistory() async {
    if (_saved) return;
    final hc = context.read<HistoryController>();
    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: widget.type,
      title: titleTr(context, widget.type),
      text: text,
      createdAt: DateTime.now(),
    );
    await hc.add(entry);
    _placeholderProvided = _looksLikePlaceholder(text);
    _saved = !_placeholderProvided;
    if (_placeholderProvided && (widget.requestExtras == null || (widget.requestExtras?.isEmpty ?? true))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndSave());
    }
  }
}

  bool _looksLikePlaceholder(String t) {
    final s = t.toLowerCase().trim();
    if (s.isEmpty) return true;
    if (s.length < 24) return true;
    return s.contains('hazir') || s.contains('hazır') || s.contains('prepar') || s.contains('loading');
  }

String _appendPersonalOutro(String type, String locale, String name, String base) {
  String who = name.trim().isEmpty ? 'Sevgili ruh' : name;
  if (type == 'coffee') {
    final tr = '($who), falinin sonlarina gelirken fincandaki sirlar sessizlesti...\n'
        'Ama enerjin hala evrenle konusuyor.\n'
        'Kaderin bir sonraki mesaji icin yeniden bir kahve pisir, niyetini dile ve fincanini hazirla.\n\n'
        'Unutma, her fincan bir anahtar...\n'
        'Ve bir sonraki kapiyi sadece MystiQ\'te acabilirsin.';
    final en = '($who), as the cup grows quiet, its secrets settle...\n'
        'Yet your energy still speaks to the universe.\n'
        'For the next message of fate, brew another coffee, set your intention, and prepare your cup.\n\n'
        'Remember, every cup is a key...\n'
        'And the next door opens only on MystiQ.';
    final add = (locale=='tr')?tr:en;
    return base.contains(add.trim()) ? base : (base.trim() + '\n\n' + add);
  }
  if (type == 'tarot') {
    final tr = '($who), acilimin sonunda bir cumlelik niyetini hatirla;\n'
        'yol haritasi kucuk ama net bir adimi isaret ediyor.\n\nKartlarin kapisi MystiQ\'te.';
    final en = '($who), at the close of the spread, recall your one-line intention;\n'
        'the roadmap points to one small, clear step.\n\nThe door of the cards is on MystiQ.';
    final add = (locale=='tr')?tr:en;
    return base.contains(add.trim()) ? base : (base.trim() + '\n\n' + add);
  }
  if (type == 'dream') {
    final tr = '($who), ruyanin izini gun icinde iki kez daha fark et;\n'
        'kucuk bir niyetle gune devam et.\n\nBir sonraki sembolu MystiQ\'te yorumlayalim.';
    final en = '($who), notice your dream\'s symbol twice today;\n'
        'continue with a small intention.\n\nLet\'s read the next sign on MystiQ.';
    final add = (locale=='tr')?tr:en;
    return base.contains(add.trim()) ? base : (base.trim() + '\n\n' + add);
  }
  if (type == 'palm') {
    final tr = '($who), avucun bugun nazik netlikte konustu;\n'
        'tek bir adimi sec ve ilerle.\n\nBir sonraki yorumu MystiQ\'te ac.';
    final en = '($who), your palm spoke with gentle clarity;\n'
        'choose one step and move.\n\nOpen the next reading on MystiQ.';
    final add = (locale=='tr')?tr:en;
    return base.contains(add.trim()) ? base : (base.trim() + '\n\n' + add);
  }
  if (type == 'astro') {
    final tr = '($who), bugun yildizlarin fısıltısını bir cumlelik niyetle tamamla;\n'
        'kucuk ama net adimlar acilir.\n\nGunun sonrasi icin MystiQ\'e bekleriz.';
    final en = '($who), close today\'s stars with one-line intention;\n'
        'small, clear steps open.\n\nSee you on MystiQ for the next one.';
    final add = (locale=='tr')?tr:en;
    return base.contains(add.trim()) ? base : (base.trim() + '\n\n' + add);
  }
  return base;
}

class _ShimmerParagraph extends StatefulWidget {
  const _ShimmerParagraph();
  @override
  State<_ShimmerParagraph> createState() => _ShimmerParagraphState();
}

class _ShimmerParagraphState extends State<_ShimmerParagraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(6, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FadeTransition(
                opacity: Tween(begin: 0.45, end: 1.0)
                    .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
                child: Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

Map<String, String> _premiumI18n(BuildContext context) {
  final loc = AppLocalizations.of(context);
  return {
    'premium.header': loc.t('premium.header'),
    'premium.closing': loc.t('premium.closing'),
    'premium.tarot.section': loc.t('premium.tarot.section'),
    'premium.coffee.section': loc.t('premium.coffee.section'),
    'premium.palm.section': loc.t('premium.palm.section'),
    'premium.dream.section': loc.t('premium.dream.section'),
    'premium.astro.section': loc.t('premium.astro.section'),
    'premium.coffee.var3': loc.t('premium.coffee.var3'),
    'premium.coffee.var2': loc.t('premium.coffee.var2'),
    'premium.coffee.var1': loc.t('premium.coffee.var1'),
    'premium.coffee.var0': loc.t('premium.coffee.var0'),
    'premium.palm.prep': loc.t('premium.palm.prep'),
    'premium.palm.line1': loc.t('premium.palm.line1'),
    'premium.palm.line2': loc.t('premium.palm.line2'),
    'premium.dream.prompt': loc.t('premium.dream.prompt'),
    'premium.astro.line1': loc.t('premium.astro.line1'),
    // AI text templates (clean UTF-8, i18n-driven)
    'ai.template.coffee': loc.t('ai.template.coffee'),
    'ai.template.tarot': loc.t('ai.template.tarot'),
    'ai.template.palm': loc.t('ai.template.palm'),
    'ai.template.dream': loc.t('ai.template.dream'),
    'ai.template.astro': loc.t('ai.template.astro'),
  };
}

String _withDailyHeader(BuildContext ctx, String type, String base) {
  if (type == 'astro') return base;
  final loc = Localizations.localeOf(ctx);
  final now = DateTime.now();
  String localeTag = loc.toLanguageTag();
  String date;
  try {
    date = DateFormat('EEEE, d MMM', localeTag).format(now);
  } catch (_) {
    date = DateFormat('EEEE, d MMM').format(now);
  }
  final ent = ctx.read<EntitlementsController>();
  final energy = ent.energy;
  final tip = AppLocalizations.of(ctx).t('daily.tip.${(((now.weekday - 1) % 7) + 1)}');
  final energyPrefix = AppLocalizations.of(ctx).t('energy.daily_prefix');
  return '$date\n$energyPrefix $energy/100\n$tip\n\n$base';
}

String _ensureMinLength(BuildContext ctx, String type, String base) {
  final loc = AppLocalizations.of(ctx);
  String t(String key, String fb) { final v = loc.t(key); return (v == key) ? fb : v; }
  final ent = ctx.read<EntitlementsController>();
  final energy = ent.energy;
  String level;
  if (energy < 50) {
    level = 'low';
  } else if (energy < 80) {
    level = 'med';
  } else {
    level = 'high';
  }
  final sep = t('deep.sep', '---');
  final hint = () {
    final kType = 'energy.' + type + '.' + level;
    final kGen = 'energy.generic.' + level;
    final tv = loc.t(kType);
    if (tv != kType) return tv;
    final gv = loc.t(kGen);
        if (gv != kGen) return gv;
    if (Localizations.localeOf(ctx).languageCode == 'tr') {
      switch (level) {
        case 'low': return 'Nazik ilerle; bir nefes ve tek niyet.';
        case 'med': return '15-20 dk tek odak iyi gelir.';
        default: return 'Bir cesur adim ekle; net bir hedef koy.';
      }
    } else {
      switch (level) {
        case 'low': return 'Keep it gentle; one breath and one intention.';
        case 'med': return '15-20 min of single-focus works well.';
        default: return 'Add a bold step; set a clear target.';
      }
    }
  }();
  final lines = <String>[base.trim(), '', sep, hint];
  // Add deeper guidance if still short
  if ((lines.join('\n')).length < 900) {
    final extras = <String>[];
    String pick(String k, String fb) { final v = loc.t(k); return v == k ? fb : v; }
    switch (type) {
      case 'tarot':
        extras.addAll([
          pick('deep.tarot.p1', '1) Odak: kart mesajini tek cumle ile not et.'),
          pick('deep.tarot.p2', '2) Iletisim: bugun nazik ve net bir sozcuk sec.'),
          pick('deep.tarot.p3', '3) Kapanis: aksama tek cumle geri bakis yaz.'),
          '4) Eylem: Bugun 20 dakikalik tek-odak zamanini ayir.',
          '5) Iliski: Bir kisiye icten bir tesekkur yolla.',
        ]);
        break;
      case 'coffee':
        extras.addAll([
          pick('deep.coffee.p1', 'Desenleri birlestir; tekrar eden izlere bak.'),
          'Kokuyu, sicakligi ve kenar izlerini birlikte yorumla.',
          'Gunun kalaninda kucuk bir niyet cumlesi yaz ve sakla.',
        ]);
        break;
      case 'palm':
        extras.addAll([
          pick('deep.palm.p1', 'Kalp ve bas cizgisini ayri ayri yorumla.'),
          'Basparmak iradeyi simgeler; gunluk ufak bir karari netlestir.',
          'Yaz: duygu/akil dengesine 3 cumle ayir.',
        ]);
        break;
      case 'dream':
        extras.addAll([
          pick('deep.dream.p1', 'Sembolunu gun icinde 3 kez fark et; not al.'),
          'Duyguyu tek kelimeyle adlandir ve 2 ornek topla.',
          'Aksam, ruyanin sana soyledigi bir minik adimi yaz.',
        ]);
        break;
      case 'astro':
        extras.addAll([
          'Gunun ritmi: 15-20 dk tek-odak + kisacik mola dongusu dene.',
          'Iletisimde netlik: bir cumlelik nezaket ve net istek yaz.',
          'Aksam: 3 cumlelik kapanis: ne ogrendin, neyi biraktin?',
        ]);
        break;
      default:
        break;
    }
    if (extras.isNotEmpty) {
      lines.add('');
      for (final e in extras) { if (e.trim().isNotEmpty) lines.add('- ' + e); }
    }
  }
  // If still short, add practical microÃ¢â‚¬â€˜steps until target length
  final targetLen = (type == 'astro') ? 2200 : 1800;
  if ((lines.join('\n')).length < targetLen) {
    final isTr = Localizations.localeOf(ctx).languageCode == 'tr';
final pads = isTr ? <String>[
  'Mikro-adim: 3 derin nefes + tek cumle niyet.',
  'Odak: 15-20 dk tek odak, sonra 3 dk mola.',
  'Iletisim: birine nazik ve net bir mesaj gonder.',
  'Kapanis: aksam uc cumle ile gunu tamamla.',
  'Beden: bir bardak su ic ve 5 dk yuru.',
  'Zihin: ertelediginden birini bugun kapat.',
] : <String>[
  'Micro-step: 3 deep breaths + one-sentence intention.',
  'Focus: 15-20 min single-focus, then a 3-min break.',
  'Communication: send one kind, clear message.',
  'Closure: end the day in three sentences.',
  'Body: drink water and take a 5-min walk.',
  'Mind: close one postponed item today.',
];
    var k = 0;
    while ((lines.join('\n')).length < targetLen && k < 24) {
      lines.add('- ' + pads[k % pads.length]);
      k++;
    }
  }
  return lines.join('\n');
}

// Test helper wrapper (public) to allow unit tests to call _ensureMinLength
String ensureMinLengthForTest(BuildContext ctx, String type, String base) =>
    _ensureMinLength(ctx, type, base);

String _title(String t) {
  switch (t) {
    case 'coffee': return 'Coffee';
    case 'tarot': return 'Tarot';
    case 'palm': return 'Palm';
    case 'dream': return 'Dream';
    case 'astro': return 'Astro';
    default: return 'MystiQ';
  }
}

String titleTr(BuildContext context, String t) {
  final loc = AppLocalizations.of(context);
  switch (t) {
    case 'coffee': return loc.t('coffee.title');
    case 'tarot': return loc.t('tarot.title');
    case 'palm': return loc.t('palm.title');
    case 'dream': return loc.t('dream.title');
    case 'astro': return loc.t('astro.title');
    default: return loc.t('app.name');
  }
}

class _TarotResultRow extends StatelessWidget {
  final List<int> indices;
  const _TarotResultRow({required this.indices});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final labels = <String>[
      loc.t('tarot.slot.past'),
      loc.t('tarot.slot.present'),
      loc.t('tarot.slot.future'),
    ];
    final n = indices.length.clamp(1, 3);
    final cards = indices.take(n).toList();
    const r = 8.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(cards.length, (i) {
            final idx = cards[i];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < cards.length - 1 ? 8 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r),
                  child: AspectRatio(
                    aspectRatio: 72/112,
                    child: SharpAssetFallback(
                      TarotDeck.frontAsset(idx),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(cards.length, (i) {
            final lab = i < labels.length ? labels[i] : '';
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < cards.length - 1 ? 8 : 0),
                child: Center(
                  child: Text(lab, style: const TextStyle(color: Colors.white70)),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _EtaBadge extends StatelessWidget {
  final int seconds;
  const _EtaBadge({required this.seconds});

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text('${loc.t('reading.eta_prefix')} ${_fmt(seconds)}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _DoneInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final text = loc.t('reading.countdown.done') != 'reading.countdown.done'
        ? loc.t('reading.countdown.done')
        : 'FalÄ±nÄ±z geÃ§miÅŸ kutusuna yÃ¶nlendirilmiÅŸtir.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}






class _DoneInfoBannerGold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final text = loc.t('reading.countdown.done') != 'reading.countdown.done'
        ? loc.t('reading.countdown.done')
        : 'Faliniz gecmis kutusuna yonlendirilmistir.';
    const gold = Color(0xFFFFC857);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0x33FFC857),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: gold, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: gold, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}


