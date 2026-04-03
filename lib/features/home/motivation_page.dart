import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/access/access_gate.dart';
import '../../core/access/sku_costs.dart';
import '../../core/readings/pending_readings_service_fixed.dart';
import '../../core/readings/reading_timing.dart';
import '../../core/util/stable_user_key.dart';
import '../history/history_controller.dart';
import '../history/history_entry.dart';
import '../profile/profile_controller.dart';

class MotivationPage extends StatefulWidget {
  const MotivationPage({super.key});
  @override
  State<MotivationPage> createState() => _MotivationPageState();
}

class _MotivationPageState extends State<MotivationPage> {
  String _text = '';
  bool _loading = false;
  bool _unlockedToday = false;
  StreamSubscription<String>? _sub;
  String _userKey = '';
  static const _kUnlockedDate = 'motivation_unlocked_date_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _redirectToPendingIfAny());
  }

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _initAccess();
  }

  String _buildTodayText() {
    try {
      String name = '';
      String zodiac = '';
      try {
        final p = context.read<ProfileController>().profile;
        name = p.name;
        zodiac = p.zodiac;
      } catch (_) {}
      final locale = Localizations.localeOf(context).languageCode;
      final now = DateTime.now();
      final dateSeed = int.parse(
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}');
      final key = _userKey.isNotEmpty ? _userKey : (name + '|' + zodiac);
      final idFactor = key.hashCode & 0x7fffffff;
      final seed = (dateSeed ^ idFactor) & 0x7fffffff;
      final loc = AppLocalizations.of(context);
      return _buildDailyMessageV2(
          loc: loc, locale: locale, name: name, zodiac: zodiac, seed: seed);
    } catch (_) {
      return '';
    }
  }

  Future<void> _initAccess() async {
    try {
      _userKey = await StableUserKey.get();
    } catch (_) {}
    final ent = context.read<EntitlementsController>();
    if (ent.isPremium) {
      _unlockedToday = true;
      _text = _buildTodayText();
      if (mounted) setState(() {});
      return;
    }
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getString(_kUnlockedDate) ?? '';
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _unlockedToday = saved == today;
      if (_unlockedToday) _text = _buildTodayText();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _unlockWithCoins() async {
    if (!mounted) return;
    final ent = context.read<EntitlementsController>();
    if (ent.isPremium) {
      _unlockedToday = true;
      await _load();
      return;
    }
    final ok = await AccessGate.ensureCoinsOnlyOrPaywall(context,
        coinCost: SkuCosts.motivation);
    if (!ok || !mounted) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await sp.setString(_kUnlockedDate, today);
    } catch (_) {}
    _unlockedToday = true;
    await _scheduleTodayMotivation();
  }

  Future<void> _redirectToPendingIfAny() async {
    try {
      final item =
          await PendingReadingsService.firstPendingOfType('motivation');
      if (!mounted || item == null) return;
      final readyAt = DateTime.tryParse((item['readyAt'] as String?) ?? '');
      if (readyAt == null) return;
      final pendingId = item['id']?.toString();
      final extras = (item['extras'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      context.push('/reading/result/motivation', extra: {
        ...extras,
        'etaSeconds':
            readyAt.difference(DateTime.now()).inSeconds.clamp(0, 86400),
        'readyAt': readyAt.toIso8601String(),
        'generateAtReady': true,
        if (pendingId != null && pendingId.isNotEmpty) 'pendingId': pendingId,
      });
    } catch (_) {}
  }

  Future<void> _scheduleTodayMotivation() async {
    if (!mounted) return;
    final preparedText = _buildTodayText();
    if (preparedText.trim().isEmpty) return;
    final eta = ReadingTiming.initialWaitFor('motivation');
    final readyAt = DateTime.now().add(eta);
    String? pendingId;
    try {
      final locale = Localizations.localeOf(context).languageCode;
      pendingId = await PendingReadingsService.schedule(
        type: 'motivation',
        readyAt: readyAt,
        extras: {
          'preparedText': preparedText,
        },
        locale: locale,
      );
      try {
        final hc = context.read<HistoryController>();
        if (pendingId != null) {
          await hc.upsert(HistoryEntry(
            id: pendingId,
            type: 'motivation',
            title: AppLocalizations.of(context).t('motivation.title'),
            text: AppLocalizations.of(context).t('reading.preparing'),
            createdAt: DateTime.now(),
          ));
        }
      } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    context.push('/reading/result/motivation', extra: {
      'preparedText': preparedText,
      'etaSeconds': eta.inSeconds,
      'readyAt': readyAt.toIso8601String(),
      'generateAtReady': true,
      if (pendingId != null) 'pendingId': pendingId,
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final ent = context.read<EntitlementsController>();
      if (!ent.isPremium && !_unlockedToday) return;
      final text = _buildTodayText();
      if (!mounted) return;
      setState(() => _text = text);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final ent = context.watch<EntitlementsController>();
    final canView = ent.isPremium || _unlockedToday;
    final now = DateTime.now();
    String date;
    try {
      date = DateFormat(
              'EEEE, d MMM', Localizations.localeOf(context).toLanguageTag())
          .format(now);
    } catch (_) {
      date = DateFormat('EEEE, d MMM').format(now);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Motivasyon'),
        actions: [
          IconButton(
              onPressed: (_loading || !canView) ? null : _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                date,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: !canView
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Günlük motivasyonu açmak için ${SkuCosts.motivation} coin gerekir.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _unlockWithCoins,
                            icon: const Icon(Icons.monetization_on_outlined),
                            label: Text('Coin ile Aç (${SkuCosts.motivation})'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/paywall'),
                            icon: const Icon(Icons.ondemand_video_outlined),
                            label: const Text('Reklam izle, coin kazan'),
                          ),
                        ],
                      ),
                    )
                  : (_loading && _text.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              _text.isEmpty ? loc.t('common.empty') : _text,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _sub?.cancel();
    } catch (_) {}
    super.dispose();
  }
}

String _buildDailyMessage(
    {required String locale,
    required String name,
    required String zodiac,
    required int seed}) {
  // Normalize locale
  final lang = const ['tr', 'en', 'es', 'ar'].contains(locale) ? locale : 'tr';
  String you = name.isNotEmpty
      ? name
      : ({
            'tr': 'Sevgili ruh',
            'es': 'Alma querida',
            'ar': 'صديقي',
            'en': 'Dear soul',
          }[lang] ??
          'Dear soul');

  List<String> introTr = [
    'Bugün ritmini küçük adımlarla kur.',
    'Niyetini tek cümlede netleştir.',
    'Kafan doluysa, nefesle başla.',
    'Gücün odaklandığın yerde büyür.',
    'Kendine yumuşak, hedefe kararlı ol.',
    'Küçük bir iyilikle güne iz bırak.',
    'Bugün “yeterince iyi” ilerleme günü.',
    'Zihnini sadeleştir, yapman gereken tek adıma dön.',
    'Cesaret, küçük bir adımın içinde saklı.',
    'Şimdi başlamak için en iyi an.',
    'Bugün kendini acele ettirmeden ilerle.',
    'Küçük bir düzenleme bile içini ferahlatabilir.',
    'Duygunu isimlendir; adı konan şey hafifler.',
    'Güne bir cümlelik niyetle yön ver.',
    'Bugün kendinle barışık kalmayı seç.',
    'Sadeleşmek, güç toplamanın bir yolu olabilir.',
  ];
  List<String> focusTr = [
    '15 dakikalık tek odak bloğu planla.',
    'Bildirimleri 20 dakika kapat.',
    'Bir kişiye nazik bir mesaj gönder.',
    'Su iç, omuzlarını gevşet, toparlan.',
    'Bugün tek net sonuç: 1 küçük tamam.',
    '“Sonraki adım”ını yaz ve uygula.',
    'Biriken işi mikroadıma böl ve başla.',
    'Kendine bir cümlelik destek yaz.',
    'Pencereyi aç, 3 derin nefes al.',
    'Günün sonunda 3 cümlelik not bırak.',
    'Masandaki tek bir şeyi düzelt; zihin de toparlanır.',
    '5 dakika yürüyüş; sonra aynı noktaya geri dön.',
    'Bir işi bitirmek için “en küçük versiyon”unu yap.',
    'Kısa bir esneme ile bedeni uyandır.',
    'Bir şeye “hayır” deyip alan aç.',
    'Bugün bir şeyi gereğinden fazla açıklama; net ol.',
  ];
  List<String> closeTr = [
    'Unutma, ilerleme kusursuzluktan güçlüdür.',
    'Günün armağanı: sakin bir zihin.',
    'Küçük ama istikrarlı kazanımlar kalıcıdır.',
    'Hafifçe başla, net bitir.',
    'Bugün kendine şefkat göstermeyi seç.',
    'Büyük resim küçük adımlarla çizilir.',
    'Zaman, niyete eşlik edince derinleşir.',
    'Yol, yürüdükçe aydınlanır.',
    'Yavaşlıkla değil, vazgeçmekle kaybedilir.',
    'Sen başlarsan hayat eşlik eder.',
    'Bugün iyi hissetmek için “küçük bir şey” yeter.',
    'İçindeki ses yumuşayınca, kararlar da netleşir.',
    'Kendini kıyaslamadan ilerlediğinde hız artar.',
    'Bugün bir şeyi yarım bırakma; küçük de olsa tamamla.',
    'Denge, her şeyi yapmak değil; doğru şeyi seçmektir.',
    'Niyetin varsa yol da vardır.',
  ];

  // English (minimal, fallback)
  List<String> introEn = [
    'Set your rhythm with small steps today.',
    'Clarify your intention in one sentence.',
    'If your mind is crowded, start with breath.',
    'Where focus goes, energy grows.',
    'Be gentle to yourself, firm to your goal.',
  ];
  List<String> focusEn = [
    'Plan a single 15-minute focus block.',
    'Silence notifications for 20 minutes.',
    'Send a kind message to one person.',
    'Drink water, relax your shoulders, reset.',
    'Write and do your next tiny step.',
  ];
  List<String> closeEn = [
    'Progress beats perfection.',
    'A calm mind is today’s gift.',
    'Small steady wins stick.',
    'Start light, finish clear.',
    'When you begin, life joins.',
  ];

  final Map<String, List<List<String>>> bank = {
    'tr': [introTr, focusTr, closeTr],
    'en': [introEn, focusEn, closeEn],
    'es': [introEn, focusEn, closeEn],
    'ar': [introEn, focusEn, closeEn],
  };

  final lists = bank[lang] ?? bank['en']!;
  int pick(int mod, int offset) => (seed + offset) % mod;
  final i1 = lists[0][pick(lists[0].length, 17)];
  final i2 = lists[1][pick(lists[1].length, 53)];
  final i3 = lists[2][pick(lists[2].length, 91)];

  final z = zodiac.isNotEmpty ? ' (${zodiac})' : '';
  final header = {
        'tr': '$you$z,',
        'es': '$you$z,',
        'ar': '$you$z،',
        'en': '$you$z,',
      }[lang] ??
      '$you$z,';

  // Always return a coherent 3-part message (not random single-liners).
  return [header, '', i1, i2, i3].join('\n');
}

String _buildDailyMessageV2({
  required AppLocalizations loc,
  required String locale,
  required String name,
  required String zodiac,
  required int seed,
}) {
  final lang = const ['tr', 'en', 'es', 'ar'].contains(locale) ? locale : 'tr';

  final you = name.isNotEmpty
      ? name
      : ({
            'tr': 'Sevgili ruh',
            'es': 'Alma querida',
            'ar': 'صديقي',
            'en': 'Dear soul',
          }[lang] ??
          'Dear soul');

  int pick(int mod, int offset) => (seed + offset) % mod;

  String lineFrom(String prefix, int count, int offset) {
    final idx = pick(count, offset);
    final key = '$prefix.$idx';
    final v = loc.t(key);
    return v == key ? '' : v;
  }

  String i1, i2, i3;
  if (lang == 'tr') {
    // Big TR pools live in assets/i18n/motivation_tr.json
    i1 = lineFrom('motivation.intro', 30, 17);
    i2 = lineFrom('motivation.action', 30, 53);
    i3 = lineFrom('motivation.closer', 30, 91);
  } else {
    const introEn = [
      'Set your rhythm with small steps today.',
      'Clarify your intention in one sentence.',
      'If your mind is crowded, start with breath.',
      'Where focus goes, energy grows.',
      'Be gentle to yourself, firm to your goal.',
    ];
    const focusEn = [
      'Plan a single 15-minute focus block.',
      'Silence notifications for 20 minutes.',
      'Send a kind message to one person.',
      'Drink water, relax your shoulders, reset.',
      'Write and do your next tiny step.',
    ];
    const closeEn = [
      'Progress beats perfection.',
      'A calm mind is today’s gift.',
      'Small steady wins stick.',
      'Start light, finish clear.',
      'When you begin, life joins.',
    ];
    i1 = introEn[pick(introEn.length, 17)];
    i2 = focusEn[pick(focusEn.length, 53)];
    i3 = closeEn[pick(closeEn.length, 91)];
  }

  final z = zodiac.isNotEmpty ? ' ($zodiac)' : '';
  final header = '$you$z,';

  final parts = <String>[
    header,
    '',
    if (i1.isNotEmpty) i1,
    if (i2.isNotEmpty) i2,
    if (i3.isNotEmpty) i3,
  ];
  return parts.join('\n');
}
