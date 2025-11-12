import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import '../../profile/profile_controller.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/readings/pending_readings_service2.dart' as pending2;
import '../../../core/analytics/analytics.dart';
import '../../../core/i18n/app_localizations.dart';
import '../tarot/tarot_deck_fixed.dart';
import '../../../common/widgets/sharp_image.dart';

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
  String? _pendingId;
  Timer? _countdown;
  DateTime? _readyAt;
  int? _remainingSeconds;
  bool _deferGenerate = false;
  bool _doneSnackShown = false;
  bool _streaming = false;

  @override
  void initState() {
    super.initState();
    try { _pendingId = (widget.requestExtras?['pendingId'] as String?); } catch (_) {}
    _initCountdownFromExtras();
    if (widget.providedText != null) {
      text = widget.providedText!;
      _placeholderProvided = _looksLikePlaceholder(text);
      _saved = !_placeholderProvided;
      if (_placeholderProvided && (widget.requestExtras == null || (widget.requestExtras?.isEmpty ?? true))) {
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
    try { _countdown?.cancel(); } catch (_) {}
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
          final it = await pending2.PendingReadingsService2.getById(pendingId);
          final ra = DateTime.tryParse((it?['readyAt'] as String?) ?? '');
          if (ra != null && (target == null || ra.isAfter(DateTime.now()))) {
            target = ra;
          }
        } catch (_) {}
      }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _generateAndSave() async {
    String locale = 'tr';
    try { locale = Localizations.localeOf(context).languageCode; } catch (_) {}
    var profile = context.mounted ? context.read<ProfileController>().profile : ProfileController().profile;
    final extras = Map<String, dynamic>.from(widget.requestExtras ?? {});
    String titleSafe;
    try { titleSafe = titleTr(context, widget.type); } catch (_) { titleSafe = _title(widget.type); }

    try {
      var generated = await AiService.generate(
        type: widget.type,
        profile: profile,
        extras: extras,
        locale: locale,
      );

      if (widget.type == 'coffee') {
        generated = _normalizeCoffeeText(generated);
        final name = profile.name;
        generated = _appendCoffeeOutro(generated, name);
      } else if (widget.type == 'tarot') {
        final name = profile.name;
        generated = _appendTarotOutro(generated, name);
      }

      if (!mounted) {
        // Persist in background even if page is closed
        await _persistDirectOrProvider(titleSafe, generated);
        try { if (_pendingId != null) await pending2.PendingReadingsService2.cancel(_pendingId!); } catch (_) {}
        _pendingId = null;
        try { await Analytics.log('reading_completed', {'type': widget.type, 'bg': true}); } catch (_) {}
        return;
      }

      setState(() { text = generated; _streaming = false; });
      await _saveToHistory();
      if (((_remainingSeconds ?? 0) == 0) && !_doneSnackShown && mounted) {
        _doneSnackShown = true;
        final loc = AppLocalizations.of(context);
        final msg = loc.t('reading.countdown.done') != 'reading.countdown.done'
            ? loc.t('reading.countdown.done')
            : 'Faliniz gecmis kutusuna yonlendirilmistir.';
        try { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); } catch (_) {}
      }
      try { if (_pendingId != null) await pending2.PendingReadingsService2.cancel(_pendingId!); } catch (_) {}
      _pendingId = null;
      try { await Analytics.log('reading_completed', {'type': widget.type}); } catch (_) {}
    } catch (_) {
      final generated = 'Uretim su anda yapilamiyor. Lutfen biraz sonra tekrar dene.';
      if (!mounted) {
        await _persistDirectOrProvider(titleSafe, generated);
        return;
      }
      setState(() { text = generated; _streaming = false; });
      await _saveToHistory();
    }
  }

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

  String _appendCoffeeOutro(String base, String name) {
    final who = name.trim().isEmpty ? '' : (name.trim() + ', ');
    const outro =
        'falinin sonlarina gelirken fincanindaki sekiller son bir kez konustu...\n'
        'Diyorlar ki: "Bu sadece baslangic."\n\n'
        'Her kahve yeni bir yol, her niyet yeni bir kapidir.\n'
        'Simdi derin bir nefes al, kalbinden dilegini gecir ve MystiQ\'e geri don...\n'
        'Evren seninle konusmaya devam etmek istiyor.';
    final header = who.isEmpty ? '' : who;
    final add = header + outro;
    final trimmed = base.trimRight();
    if (trimmed.endsWith(outro)) return base; // already added
    return trimmed + '\n\n' + add;
  }

  String _appendTarotOutro(String base, String name) {
    final who = name.trim().isEmpty ? '' : (name.trim() + ', ');
    const outro =
        'falinin sonlarina gelirken tarot kartindaki sekiller son bir kez konustu...\n'
        'Diyorlar ki: "Bu sadece baslangic."\n\n'
        'Her sectigin kart yeni bir yol, her niyet yeni bir kapidir.\n'
        'Simdi derin bir nefes al, kalbinden dilegini gecir ve MystiQ\'e geri don...\n'
        'Evren seninle konusmaya devam etmek istiyor.';
    final header = who.isEmpty ? '' : who;
    final add = header + outro;
    final trimmed = base.trimRight();
    if (trimmed.endsWith(outro)) return base; // already added
    return trimmed + '\n\n' + add;
  }

  Future<void> _persistDirectOrProvider(String title, String generated) async {
    try {
      final usedId = _pendingId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final entry = HistoryEntry(
        id: usedId,
        type: widget.type,
        title: title,
        text: generated,
        createdAt: DateTime.now(),
      );
      try {
        final hcEarly = context.read<HistoryController>();
        try { await hcEarly.upsert(entry); } catch (_) { await _saveHistoryDirect(entry); }
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
          if ((m['id'] as String?) == e.id) { idx = i; break; }
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
    final usedId = _pendingId ?? DateTime.now().millisecondsSinceEpoch.toString();
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
    final fav = entryId == null
        ? false
        : hc.items.firstWhere(
            (e) => e.id == entryId,
            orElse: () => HistoryEntry(id: '', type: '', title: '', text: '', createdAt: DateTime.now()),
          ).favorite;

    // Optional tarot cards row (front faces)
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
            if (widget.type == 'tarot' && cardIdxs != null && cardIdxs.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TarotFrontRow(indices: cardIdxs.take(3).toList()),
            ],
            if ((_remainingSeconds ?? 0) > 0) ...[
              const SizedBox(height: 6),
              _EtaBadge(seconds: _remainingSeconds!),
            ],
            // Coffee sonucu hazir olana kadar bilgilendirici metin
            if (widget.type == 'coffee' && text.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).t('coffee.waiting') != 'coffee.waiting'
                    ? AppLocalizations.of(context).t('coffee.waiting')
                    : 'Kahve faliniz hazirlaniyor, lutfen bekleyiniz...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            // Palm sonucu hazir olana kadar bilgilendirici metin
            if (widget.type == 'palm' && text.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).t('palm.waiting') != 'palm.waiting'
                    ? AppLocalizations.of(context).t('palm.waiting')
                    : 'El faliniza bakiliyor, lutfen bekleyin... ',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            // Tarot sonucu hazir olana kadar bilgilendirici metin
            if (widget.type == 'tarot' && text.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).t('tarot.waiting') != 'tarot.waiting'
                    ? AppLocalizations.of(context).t('tarot.waiting')
                    : 'Tarot faliniz hazirlaniyor, lutfen bekleyin...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            // Astro sonucu hazir olana kadar bilgilendirici metin
            if (widget.type == 'astro' && text.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).t('astro.waiting') != 'astro.waiting'
                    ? AppLocalizations.of(context).t('astro.waiting')
                    : 'Gunluk burc yorumunuz hazirlaniyor, lutfen bekleyiniz...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: text.isEmpty
                  ? const _ShimmerParagraph()
                  : SingleChildScrollView(child: SelectableText(text)),
            ),
            const SizedBox(height: 8),
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
}

bool _looksLikePlaceholder(String t) {
  final s = t.toLowerCase().trim();
  if (s.isEmpty) return true;
  if (s.length < 24) return true;
  return s.contains('hazir') || s.contains('hazÄ±r') || s.contains('prepar') || s.contains('loading');
}

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

// Simple shimmer placeholder lines
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
String ensureMinLengthForTest(BuildContext ctx, String type, String base) => base.trim();

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
    );
  }
}
