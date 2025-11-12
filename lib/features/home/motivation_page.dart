import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../profile/profile_controller.dart';

class MotivationPage extends StatefulWidget {
  const MotivationPage({super.key});
  @override
  State<MotivationPage> createState() => _MotivationPageState();
}

class _MotivationPageState extends State<MotivationPage> {
  String _text = '';
  bool _loading = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
  }

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
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
      final dateSeed = int.parse('${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}');
      final idFactor = (name + '|' + zodiac).hashCode & 0x7fffffff;
      final seed = (dateSeed ^ idFactor) & 0x7fffffff;
      _text = _buildDailyMessage(locale: locale, name: name, zodiac: zodiac, seed: seed);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      String name = '';
      String zodiac = '';
      try {
        final p = context.read<ProfileController>().profile;
        name = p.name;
        zodiac = p.zodiac;
      } catch (_) {
        // Provider erişilemiyorsa varsayılana düş
      }
      final locale = Localizations.localeOf(context).languageCode;
      final now = DateTime.now();
      final dateSeed = int.parse('${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}');
      final idFactor = (name + '|' + zodiac).hashCode & 0x7fffffff;
      final seed = (dateSeed ^ idFactor) & 0x7fffffff;
      final text = _buildDailyMessage(locale: locale, name: name, zodiac: zodiac, seed: seed);
      if (!mounted) return;
      setState(() => _text = text);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    String date;
    try {
      date = DateFormat('EEEE, d MMM', Localizations.localeOf(context).toLanguageTag()).format(now);
    } catch (_) {
      date = DateFormat('EEEE, d MMM').format(now);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gunluk Motivasyon'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading && _text.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Text(
                          _text.isEmpty ? loc.t('common.empty') : _text,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    try { _sub?.cancel(); } catch (_) {}
    super.dispose();
  }
}

String _buildDailyMessage({required String locale, required String name, required String zodiac, required int seed}) {
  // Normalize locale
  final lang = const ['tr','en','es','ar'].contains(locale) ? locale : 'en';
  String you = name.isNotEmpty ? name : (
    {
      'tr': 'Sevgili ruh',
      'es': 'Alma querida',
      'ar': 'صديقي',
      'en': 'Dear soul',
    }[lang] ?? 'Dear soul'
  );

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
    'Şimdi başlamak için en iyi an.'
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
    'Günün sonunda 3 cümlelik not bırak.'
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
    'Sen başlarsan evren eşlik eder.'
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

  Map<String, List<List<String>>> bank = {
    'tr': [introTr, focusTr, closeTr],
    'en': [introEn, focusEn, closeEn],
    'es': [introEn, focusEn, closeEn],
    'ar': [introEn, focusEn, closeEn],
  };

  final lists = bank[lang] ?? bank['en']!;
  // Single-sentence per-user, per-day message
  {
    final pool = <String>[...lists[0], ...lists[1], ...lists[2]];
    if (pool.isNotEmpty) {
      final idx = (seed % pool.length).abs();
      final z = zodiac.isNotEmpty ? ' (${zodiac})' : '';
      final header = {
        'tr': '$you$z,',
        'es': '$you$z,',
        'ar': '$you$z',
        'en': '$you$z,',
      }[lang] ?? '$you$z,';
      return header + ' ' + pool[idx];
    }
  }
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
  }[lang] ?? '$you$z,';

  return [header, '', i1, i2, i3].join('\n');
}
