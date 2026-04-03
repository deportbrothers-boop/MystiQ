import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import '../../profile/profile_controller.dart';
import '../../profile/user_profile.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ai/local_generator.dart';
import '../../../core/readings/pending_readings_service_fixed.dart';
import '../../../core/readings/reading_timing.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/i18n/app_localizations.dart';
import '../tarot/tarot_deck_fixed.dart';
import '../../../common/widgets/sharp_image.dart';
import '../../../core/entitlements/entitlements_controller.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/ads/ad_service.dart';
import '../../../core/access/ai_generation_guard.dart';
import '../../../core/ads/rewarded_helper.dart';

class ReadingResultPage extends StatefulWidget {
  final String type; // coffee | tarot | palm | dream | astro
  final String? providedText; // from history
  final Map<String, dynamic>?
      requestExtras; // imagePath, text, cardIndices, delay, unlockMethod
  const ReadingResultPage(
      {super.key, required this.type, this.providedText, this.requestExtras});

  @override
  State<ReadingResultPage> createState() => _ReadingResultPageState();
}

class _ReadingResultPageState extends State<ReadingResultPage> {
  String text = '';
  bool _saved = false;
  bool _placeholderProvided = false;
  String? _pendingId;
  Timer? _countdown;
  DateTime? _readyAt;
  int? _remainingSeconds;
  bool _deferGenerate = false;
  bool _doneSnackShown = false;
  bool _streaming = false;
  bool _speedupUsed = false;
  bool _speedingUp = false;

  bool _isAiFailure(String s) =>
      s.trim().startsWith('Uretim su anda yapilamiyor');

  Duration get _speedupTargetEta => ReadingTiming.speedupTargetFor(widget.type);
  String get _speedupTargetLabel =>
      ReadingTiming.speedupTargetLabel(widget.type);

  bool _shouldBackToHome() {
    // Kahve yorumunun geri sayım ekranında geri tuşu ana menüye dönsün.
    final left = (_remainingSeconds ?? 0);
    if (widget.type != 'coffee') return false;
    if (left <= 0) return false;
    return true;
  }

  void _goHome() {
    try {
      context.go('/home');
    } catch (_) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  String _fallbackText({required UserProfile profile, required String locale}) {
    try {
      return LocalAIGenerator.generate(
        type: widget.type,
        profile: profile,
        extras: widget.requestExtras,
        locale: locale,
      );
    } catch (_) {
      if (widget.type == 'coffee') {
        final name =
            profile.name.trim().isEmpty ? 'Dostum' : profile.name.trim();
        return 'Kahve Yorumu\n\n$name, fincandaki şekiller sembolik çağrışımlar veriyor.\n\nBugünün Mini Önerileri:\n- Bugün kısa bir mesajla bağ kur.\n- 2 dakika nefesle sakinleş.\n\nFincanın sonuna geliyorken, yeni bir fincanla tekrar geldiğinde kaldığımız yerden devam ederiz.\n\nBu içerik eğlence amaçlıdır; kesinlik içermez.';
      }
      return 'Yorum şu an oluşturulamadı; biraz sonra tekrar deneyebilirsin.\n\nBu içerik eğlence amaçlıdır; kesinlik içermez.';
    }
  }

  Future<void> _refundCoinsIfNeeded() async {
    try {
      final ent = context.read<EntitlementsController>();
      if (ent.lastUnlockMethod != 'coins') return;
      int cost = 0;
      switch (widget.type) {
        case 'dream':
          cost = SkuCosts.dream;
          break;
        case 'tarot':
          cost = SkuCosts.tarotDeep;
          break;
        case 'coffee':
          cost = SkuCosts.coffeeFast;
          break;
        case 'palm':
          cost = SkuCosts.palmPremium;
          break;
        default:
          return;
      }
      await ent.addCoins(cost);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    try {
      _pendingId = (widget.requestExtras?['pendingId'] as String?);
    } catch (_) {}
    _initCountdownFromExtras();
    if (widget.providedText != null) {
      text = widget.providedText!;
      _placeholderProvided = _looksLikePlaceholder(text);
      if (widget.type == 'coffee' && !_placeholderProvided) {
        text = AiService.postProcessCoffeeText(text);
      }
      _saved = !_placeholderProvided;
      final hasPermit = ((widget.requestExtras?['permit'] ?? '')
          .toString()
          .trim()
          .isNotEmpty);
      if (_placeholderProvided && hasPermit) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndSave());
      }
    } else {
      final e = widget.requestExtras ?? const <String, dynamic>{};
      final noStream = e['noStream'] == true;
      _deferGenerate = e['generateAtReady'] == true;
      if (noStream && !_deferGenerate) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndSave());
      } else if (!_deferGenerate) {
        // Not streaming here; simply generate once
        WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndSave());
      }
    }
  }

  @override
  void dispose() {
    try {
      _countdown?.cancel();
    } catch (_) {}
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
      final pendingId = e['pendingId'] as String?;
      if (pendingId != null) {
        try {
          final used = await PendingReadingsService.isSpeedupUsed(pendingId);
          if (mounted) setState(() => _speedupUsed = used);
        } catch (_) {}
        try {
          final it = await PendingReadingsService.getById(pendingId);
          final ra = DateTime.tryParse((it?['readyAt'] as String?) ?? '');
          if (mounted) {
            setState(() {
              _pendingId = pendingId;
            });
          }
          if (ra != null && (target == null || ra.isAfter(DateTime.now()))) {
            target = ra;
          }
        } catch (_) {}
      }
      if (target == null) return;
      _readyAt = target;
      _tickCountdown();
      _countdown?.cancel();
      _countdown =
          Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
    } catch (_) {}
  }

  Future<void> _speedUpToTarget() async {
    final id = _pendingId;
    if (id == null || id.isEmpty) return;
    final targetEta = _speedupTargetEta;
    if (targetEta <= Duration.zero) return;
    final left = _remainingSeconds ?? 0;
    if (left <= targetEta.inSeconds) return;
    if (_speedingUp || _speedupUsed) return;

    setState(() => _speedingUp = true);
    try {
      final ok = await RewardedAds.show(context: context);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Reklam gösterilemedi. Tekrar deneyin.')),
        );
        return;
      }

      // Re-check from storage so re-entry / multiple taps can't bypass the one-time rule.
      final alreadyUsed = await PendingReadingsService.isSpeedupUsed(id);
      if (alreadyUsed) {
        if (mounted) setState(() => _speedupUsed = true);
        return;
      }

      String locale = 'tr';
      try {
        locale = Localizations.localeOf(context).languageCode;
      } catch (_) {}

      final newReadyAt = DateTime.now().add(targetEta);
      try {
        await PendingReadingsService.updateReadyAt(
          id: id,
          type: widget.type,
          readyAt: newReadyAt,
          locale: locale,
        );
      } catch (_) {}
      try {
        await PendingReadingsService.markSpeedupUsed(id);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _readyAt = newReadyAt;
        _speedupUsed = true;
      });
      _tickCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Hızlandırıldı: Sonuç ~5 dk içinde hazır.')),
      );
    } finally {
      if (mounted) setState(() => _speedingUp = false);
    }
  }

  void _tickCountdown() {
    if (_readyAt == null) return;
    final left = _readyAt!.difference(DateTime.now()).inSeconds;
    final rem = left > 0 ? left : 0;
    if (!mounted) return;
    setState(() {
      _remainingSeconds = rem;
    });
    if (left <= 0) {
      try {
        _countdown?.cancel();
      } catch (_) {}
      if (_deferGenerate &&
          (!_saved) &&
          (text.isEmpty || _placeholderProvided)) {
        _generateAndSave();
      }
      if (!_doneSnackShown && mounted) {
        _doneSnackShown = true;
        final loc = AppLocalizations.of(context);
        final msg = loc.t('reading.countdown.done') != 'reading.countdown.done'
            ? loc.t('reading.countdown.done')
            : 'Yorumunuz gecmis kutusuna yonlendirilmistir.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _generateAndSave() async {
    String locale = 'tr';
    try {
      locale = Localizations.localeOf(context).languageCode;
    } catch (_) {}
    var profile = context.mounted
        ? context.read<ProfileController>().profile
        : ProfileController().profile;
    final extras = Map<String, dynamic>.from(widget.requestExtras ?? {});
    final preparedText = (extras['preparedText'] ?? '').toString().trim();
    String titleSafe;
    try {
      titleSafe = titleTr(context, widget.type);
    } catch (_) {
      titleSafe = _title(widget.type);
    }

    // If a background pending job already completed, prefer the saved history text
    // to avoid a second AI call (and permit re-consumption).
    final pid = _pendingId ?? (extras['pendingId'] as String?);
    if (pid != null && pid.isNotEmpty) {
      try {
        final hc = context.read<HistoryController>();
        final existing = hc.items.firstWhere((e) => e.id == pid);
        if (!_looksLikePlaceholder(existing.text)) {
          var readyText = existing.text;
          if (widget.type == 'coffee') {
            readyText = AiService.postProcessCoffeeText(readyText);
          } else if (widget.type == 'tarot') {
            readyText = _appendTarotOutro(readyText, profile.name);
          }
          if (!mounted) return;
          setState(() {
            text = readyText;
            _saved = true;
            _placeholderProvided = false;
            _streaming = false;
          });
          try {
            await PendingReadingsService.cancel(pid);
          } catch (_) {}
          _pendingId = null;
          return;
        }
      } catch (_) {}
    }

    try {
      var generated = preparedText.isNotEmpty
          ? preparedText
          : await AiService.generate(
              type: widget.type,
              profile: profile,
              extras: extras,
              locale: locale,
            );

      if (generated.trim().isEmpty || _isAiFailure(generated)) {
        generated = _fallbackText(profile: profile, locale: locale);
      }

      if (widget.type == 'coffee') {
        generated = AiService.postProcessCoffeeText(generated);
      } else if (widget.type == 'tarot') {
        final name = profile.name;
        generated = _appendTarotOutro(generated, name);
      }

      if (!mounted) {
        // Persist in background even if page is closed
        await _persistDirectOrProvider(titleSafe, generated);
        try {
          if (_pendingId != null)
            await PendingReadingsService.cancel(_pendingId!);
        } catch (_) {}
        _pendingId = null;
        try {
          await Analytics.log(
              'reading_completed', {'type': widget.type, 'bg': true});
        } catch (_) {}
        return;
      }

      setState(() {
        text = generated;
        _streaming = false;
        _placeholderProvided = false;
      });
      await _saveToHistory();
      if (((_remainingSeconds ?? 0) == 0) && !_doneSnackShown && mounted) {
        _doneSnackShown = true;
        final loc = AppLocalizations.of(context);
        final msg = loc.t('reading.countdown.done') != 'reading.countdown.done'
            ? loc.t('reading.countdown.done')
            : 'Yorumunuz gecmis kutusuna yonlendirilmistir.';
        try {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        } catch (_) {}
      }
      try {
        if (_pendingId != null)
          await PendingReadingsService.cancel(_pendingId!);
      } catch (_) {}
      _pendingId = null;
      try {
        await Analytics.log('reading_completed', {'type': widget.type});
      } catch (_) {}
    } on AiGenerationGuardException catch (_) {
      // Permit missing or already consumed: do not attempt fallback generation.
      // If history has the final text it will be shown via the early-return above.
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final msg = l.t('error.generic') != 'error.generic'
          ? l.t('error.generic')
          : 'Bu işlem için önce erişim alınması gerekiyor.';
      try {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      } catch (_) {}
      return;
    } catch (_) {
      final generated = _fallbackText(profile: profile, locale: locale);
      if (!mounted) {
        await _persistDirectOrProvider(titleSafe, generated);
        try {
          if (_pendingId != null)
            await PendingReadingsService.cancel(_pendingId!);
        } catch (_) {}
        _pendingId = null;
        return;
      }
      setState(() {
        text = generated;
        _streaming = false;
        _placeholderProvided = false;
      });
      await _saveToHistory();
      try {
        if (_pendingId != null)
          await PendingReadingsService.cancel(_pendingId!);
      } catch (_) {}
      _pendingId = null;
      return;
    }
  }

  String _userName() {
    try {
      final p = context.read<ProfileController>().profile;
      final n = p.name.trim();
      return n.isNotEmpty ? n : 'Dostum';
    } catch (_) {
      return 'Dostum';
    }
  }

  bool _shouldShowReengagementCta(String currentText) {
    if (currentText.trim().isEmpty) return false;
    // Coffee already includes a strict outro; avoid duplicating.
    if (widget.type == 'coffee') return false;
    if (widget.type == 'motivation') return false;
    return true;
  }

  bool get _isPreparingState => text.isEmpty || _placeholderProvided;

  String _preparingDescription(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final message = loc.t('reading.preparing.detail');
    if (message != 'reading.preparing.detail') return message;
    return 'Yorumunuz hazırlanıyor, lütfen bekleyin...';
  }

  String _reengagementCtaText() {
    final name = _userName();
    final prefix = name.isNotEmpty ? '$name, ' : '';
    switch (widget.type) {
      case 'tarot':
        return '${prefix}kartların sonuna gelirken küçük bir detay daha kaldı… İstersen aynı açılımı 2. kez yorumlayalım; bazen ikinci bakış daha çok şey söyler.';
      case 'dream':
        return '${prefix}rüyanın sonuna gelirken küçük bir iz daha beliriyor… İstersen aynı rüyayı 2. kez yorumlayalım; bazen ikinci bakış duyguyu daha net yakalar.';
      case 'palm':
        return '${prefix}çizgilerin sonuna gelirken küçük bir ayrıntı daha var… İstersen aynı eli 2. kez yorumlayalım; bazen ikinci bakış daha fazla ipucu taşır.';
      case 'astro':
        return '${prefix}günün yorumunu kapatırken küçük bir detay daha kaldı… Yarın tekrar geldiğinde ritim daha netleşebilir.';
      default:
        return '${prefix}yorumun sonuna gelirken küçük bir detay daha kaldı… Yeniden baktığında resim daha netleşebilir.';
    }
  }

  // ignore: unused_element
  String _normalizeCoffeeText(String s) {
    // Remove markdown bold/italic markers
    var out = s.replaceAll(RegExp(r"\*\*(.*?)\*\*"), r"$1");
    out = out.replaceAll(RegExp(r"\*(.*?)\*"), r"$1");
    out = out.replaceAll(RegExp(r"_(.*?)_"), r"$1");
    // Drop list markers at line starts: numbers (1., 1), bullets (*, -, â€¢)
    out = out.replaceAll(RegExp(r"(?m)^\s*(?:\d+[\.)]|[\*\-â€¢])\s*"), "");
    // Collapse excessive blank lines
    out = out.replaceAll(RegExp(r"\n{3,}"), "\n\n");
    // Trim spaces around lines
    out = out.split('\n').map((l) => l.trimRight()).join('\n');
    return out.trim();
  }

  String _appendTarotOutro(String base, String name) {
    final who = name.trim().isEmpty ? '' : (name.trim() + ', ');
    const outro = 'kartlardaki semboller, tematik bir bakisla yorumlanabilir.\n'
        'Bu yorum eglence amaclidir; kendi sezgini de referans al.';
    final header = who.isEmpty ? '' : who;
    final add = header + outro;
    final trimmed = base.trimRight();
    if (trimmed.endsWith(outro)) return base; // already added
    return trimmed + '\n\n' + add;
  }

  Future<void> _persistDirectOrProvider(String title, String generated) async {
    try {
      final usedId =
          _pendingId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final entry = HistoryEntry(
        id: usedId,
        type: widget.type,
        title: title,
        text: generated,
        createdAt: DateTime.now(),
      );
      try {
        final hcEarly = context.read<HistoryController>();
        try {
          await hcEarly.upsert(entry);
        } catch (_) {
          await _saveHistoryDirect(entry);
        }
      } catch (_) {
        await _saveHistoryDirect(entry);
      }
    } catch (_) {}
  }

  // Fallback writer when Provider is unavailable (e.g., page closed before saving)
  Future<void> _saveHistoryDirect(HistoryEntry e) async {
    try {
      final sp = await SharedPreferences.getInstance();
      const key = 'history_entries_v1';
      final list = sp.getStringList(key) ?? <String>[];
      int idx = -1;
      for (var i = 0; i < list.length; i++) {
        try {
          final m = json.decode(list[i]) as Map<String, dynamic>;
          if ((m['id'] as String?) == e.id) {
            idx = i;
            break;
          }
        } catch (_) {}
      }
      final enc = json.encode(e.toJson());
      if (idx >= 0) {
        list[idx] = enc;
      } else {
        list.insert(0, enc);
      }
      await sp.setStringList(key, list);
    } catch (_) {}
  }

  Future<void> _saveToHistory() async {
    if (_saved) return;
    final hc = context.read<HistoryController>();
    final usedId =
        _pendingId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final entry = HistoryEntry(
      id: usedId,
      type: widget.type,
      title: titleTr(context, widget.type),
      text: text,
      createdAt: DateTime.now(),
    );
    if (_pendingId != null) {
      await hc.upsert(entry);
    } else {
      await hc.add(entry);
    }
    _placeholderProvided = _looksLikePlaceholder(text);
    _saved = !_placeholderProvided;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final hc = context.watch<HistoryController>();
    final entryId = _entryId(hc);
    final isPreparing = _isPreparingState;
    final fav = entryId == null
        ? false
        : hc.items
            .firstWhere(
              (e) => e.id == entryId,
              orElse: () => HistoryEntry(
                  id: '',
                  type: '',
                  title: '',
                  text: '',
                  createdAt: DateTime.now()),
            )
            .favorite;

    // Optional tarot cards row (front faces)
    final List<int>? cardIdxs = (widget.requestExtras?['cardIndices'] is List)
        ? (widget.requestExtras!['cardIndices'] as List)
            .map((e) => int.tryParse('$e') ?? -1)
            .where((e) => e >= 0)
            .toList()
        : null;

    final backToHome = _shouldBackToHome();

    final page = Scaffold(
      appBar: AppBar(
        title: Text(loc.t('reading.result.title')),
        leading: backToHome
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goHome,
              )
            : null,
        actions: [
          if (entryId != null)
            IconButton(
              icon: Icon(fav ? Icons.star : Icons.star_border),
              onPressed: () => hc.toggleFavorite(entryId),
            ),
          IconButton(
            tooltip: AppLocalizations.of(context).t('action.copy'),
            icon: const Icon(Icons.copy),
            onPressed: isPreparing
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(loc.t('action.copied'))));
                    }
                  },
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(top: false, child: AdBanner()),
      body: SafeArea(
        // Alt sistem gezinme çubuğu (gesture/3‑buton) üstünde kalması için
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titleTr(context, widget.type),
                  style: Theme.of(context).textTheme.titleLarge),
              if (widget.type == 'tarot' &&
                  cardIdxs != null &&
                  cardIdxs.isNotEmpty) ...[
                const SizedBox(height: 8),
                _TarotFrontRow(indices: cardIdxs.take(3).toList()),
              ],
              if ((_remainingSeconds ?? 0) > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    _EtaBadge(seconds: _remainingSeconds!),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
              if (isPreparing) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            loc.t('reading.preparing') != 'reading.preparing'
                                ? loc.t('reading.preparing')
                                : 'Hazırlanıyor...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _preparingDescription(context),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: isPreparing
                    ? const _ShimmerParagraph()
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(text),
                            if (_shouldShowReengagementCta(text)) ...[
                              const SizedBox(height: 16),
                              Text(
                                _reengagementCtaText(),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              if (isPreparing &&
                  (_remainingSeconds ?? 0) > _speedupTargetEta.inSeconds &&
                  _pendingId != null &&
                  !_speedupUsed) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _speedingUp ? null : _speedUpToTarget,
                    icon: _speedingUp
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rocket_launch, size: 18),
                    label: const Text('Reklam izle • 5 dk’ya hızlandır'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Bu fal için hedef kalan süre: $_speedupTargetLabel',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  ElevatedButton(
                    onPressed: isPreparing
                        ? null
                        : () => Share.share(text,
                            subject: titleTr(context, widget.type)),
                    child: Text(loc.t('action.share')),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(loc.t('action.close')),
                  ),
                ],
              ),
              if (widget.type == 'coffee') ...[
                const SizedBox(height: 8),
                const Text(
                  'Bu içerik eğlence amaçlıdır. Kesinlik içermez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!backToHome) return page;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _goHome();
      },
      child: page,
    );
  }

  String? _entryId(HistoryController hc) {
    try {
      final e =
          hc.items.firstWhere((e) => e.text == text && e.type == widget.type);
      return e.id;
    } catch (_) {
      return null;
    }
  }
}

bool _looksLikePlaceholder(String t) {
  final s = t.toLowerCase().trim();
  if (s.isEmpty) return true;
  if (s.length < 24) return true;
  return s.contains('hazir') ||
      s.contains('hazır') ||
      s.contains('prepar') ||
      s.contains('loading');
}

String _title(String t) {
  switch (t) {
    case 'coffee':
      return 'Kahve Yorumu';
    case 'tarot':
      return 'Tarot';
    case 'palm':
      return 'El Çizgisi Yorumu';
    case 'dream':
      return 'Rüya Tabiri';
    case 'astro':
      return 'Astroloji';
    case 'motivation':
      return 'Günlük Motivasyon';
    default:
      return 'MystiQ';
  }
}

String titleTr(BuildContext context, String t) {
  final loc = AppLocalizations.of(context);
  switch (t) {
    case 'coffee':
      return loc.t('coffee.title');
    case 'tarot':
      return loc.t('tarot.title');
    case 'palm':
      return loc.t('palm.title');
    case 'dream':
      return loc.t('dream.title');
    case 'astro':
      return loc.t('astro.title');
    case 'motivation':
      return loc.t('motivation.title');
    default:
      return loc.t('app.name');
  }
}

// Simple shimmer placeholder lines
class _ShimmerParagraph extends StatefulWidget {
  const _ShimmerParagraph();
  @override
  State<_ShimmerParagraph> createState() => _ShimmerParagraphState();
}

class _ShimmerParagraphState extends State<_ShimmerParagraph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(6, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: FadeTransition(
              opacity: Tween(begin: 0.45, end: 1.0).animate(
                  CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
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
    );
  }
}

class _EtaBadge extends StatelessWidget {
  final int seconds;
  const _EtaBadge({required this.seconds});
  @override
  Widget build(BuildContext context) {
    final d = Duration(seconds: seconds);
    String two(int n) => n.toString().padLeft(2, '0');
    final label = '${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

// Test helper retained for existing tests
String ensureMinLengthForTest(BuildContext ctx, String type, String base) =>
    _ensureMinLength(ctx, base);

String _ensureMinLength(BuildContext ctx, String base) {
  final t = base.trim();
  if (t.length >= 24) return t;
  int energy = 70;
  try {
    energy = ctx.read<EntitlementsController>().energy;
  } catch (_) {}

  final loc = AppLocalizations.of(ctx);
  final key = energy < 40
      ? 'energy.generic.low'
      : (energy < 80 ? 'energy.generic.med' : 'energy.generic.high');
  final hint = loc.t(key);
  final safeHint = hint != key
      ? hint
      : (Localizations.localeOf(ctx).languageCode == 'tr'
          ? 'Enerji: küçük bir nefes + tek niyetle başla.'
          : 'Low energy: one breath and one intention.');

  return '$t\n\n$safeHint';
}

class _TarotFrontRow extends StatelessWidget {
  final List<int> indices;
  const _TarotFrontRow({required this.indices});
  @override
  Widget build(BuildContext context) {
    final cards = indices.take(3).toList();
    const radius = 10.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(cards.length, (i) {
        final idx = cards[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < cards.length - 1 ? 8 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: AspectRatio(
                aspectRatio: 72 / 112,
                child: SharpAssetFallback(
                  TarotDeck.frontAsset(idx),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
