import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/mystiq_background.dart';
import '../../../common/widgets/scanning_overlay.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/ai_generation_guard.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/entitlements/entitlements_controller.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/readings/coffee_image_inspector.dart';
import '../../../core/readings/pending_readings_service_fixed.dart';
import '../../../core/readings/reading_timing.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import 'package:falla/features/readings/coffee/_thumb_slot.dart';

class CoffeePage extends StatefulWidget {
  const CoffeePage({super.key});
  @override
  State<CoffeePage> createState() => _CoffeePageState();
}

class _CoffeePageState extends State<CoffeePage>
    with SingleTickerProviderStateMixin {
  File? cup1;
  File? cup2;
  File? saucer;
  bool scanning = false;
  late final AnimationController _pulse;
  String? _scheduledId;
  Duration? _eta; // last selected ETA (10m or 5m)
  String? _permit;
  String _topic = 'general';
  String _style = 'practical'; // 'practical' | 'spiritual' | 'analytical'
  Duration get _defaultEta => ReadingTiming.initialWaitFor('coffee');

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    // If a pending coffee exists, redirect directly to Result with countdown
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final item = await PendingReadingsService.firstPendingOfType('coffee');
        if (!mounted || item == null) return;
        final readyAt = DateTime.tryParse((item['readyAt'] as String?) ?? '');
        if (readyAt == null) return;
        final pendingId = item['id']?.toString();
        final extras = (item['extras'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final paths =
            (extras['imagePaths'] as List?)?.map((e) => '$e').toList() ??
                const <String>[];
        if (!mounted) return;
        context.push('/reading/result/coffee', extra: {
          if (paths.isNotEmpty) 'imagePaths': paths,
          if ((extras['permit'] ?? '').toString().trim().isNotEmpty)
            'permit': extras['permit'],
          'etaSeconds':
              readyAt.difference(DateTime.now()).inSeconds.clamp(0, 86400),
          'readyAt': readyAt.toIso8601String(),
          'generateAtReady': true,
          if (pendingId != null && pendingId.isNotEmpty) 'pendingId': pendingId,
          // streaming/local flags removed
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _startReading({required bool viaAd}) async {
    final selectedCount = [cup1, cup2, saucer].where((e) => e != null).length;
    if (selectedCount == 0) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('coffee.snackbar.missing'))),
      );
      return;
    }

    // Boş fincan/iz yoksa: kesinlikle yorum üretme.
    try {
      String? emptyLabel;
      if (cup1 != null) {
        final r = await CoffeeImageInspector.looksEmpty(cup1!.path);
        if (r == true) emptyLabel = 'Fincan 1';
      }
      if (emptyLabel == null && cup2 != null) {
        final r = await CoffeeImageInspector.looksEmpty(cup2!.path);
        if (r == true) emptyLabel = 'Fincan 2';
      }
      if (emptyLabel == null && saucer != null) {
        final r = await CoffeeImageInspector.looksEmpty(saucer!.path);
        if (r == true) emptyLabel = 'Tabak';
      }
      if (!mounted) return;
      if (emptyLabel != null) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Bilgilendirme'),
            content: Text(
              '$emptyLabel görselinde henüz yorumlanabilecek izler oluşmamış.\n\n'
              'Kahve içildikten sonra telve fincanın içinde iz bıraktığında daha sağlıklı bir yorum yapabiliriz.\n\n'
              'Hazır olduğunda fincanını tekrar gönderebilirsin.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tamam')),
            ],
          ),
        );
        return;
      }
    } catch (_) {}

    await Analytics.log('reading_started', {'type': 'coffee'});
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    final adOkText = loc.t('coffee.entry.ad_ok') != 'coffee.entry.ad_ok'
        ? loc.t('coffee.entry.ad_ok')
        : '2 reklam izlendi. Sonuc yaklasik 10 dk icinde hazir.';
    final adFailedText =
        loc.t('coffee.fast.ad_failed') != 'coffee.fast.ad_failed'
            ? loc.t('coffee.fast.ad_failed')
            : 'Reklam gosterilemedi. Tekrar deneyin.';

    // Akışlar:
    // - Reklam ile: 2 reklam + 10 dk bekleme
    // - Coin ile: beklemeden (0 dk) doğrudan üretim
    Duration eta = _defaultEta;
    bool adUsed = false;

    if (viaAd) {
      try {
        final ok = await RewardedAds.showMultiple(
            context: context, count: 2, key: 'coffee');
        if (!mounted) return;
        if (ok) {
          adUsed = true;
          _permit = await AiGenerationGuard.issuePermit();
          // Reklamdan sonra bekleme 10 dk kalır.
          messenger.showSnackBar(
            SnackBar(content: Text(adOkText)),
          );
        } else {
          if (kDebugMode) {
            _permit = await AiGenerationGuard.issuePermit();
            eta = Duration.zero;
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                    'Debug mod: reklam yuklenemedi, reklam atlandi ve yorum dogrudan baslatildi.'),
              ),
            );
          } else {
            messenger.showSnackBar(SnackBar(content: Text(adFailedText)));
            return;
          }
        }
      } catch (_) {
        if (!mounted) return;
        if (kDebugMode) {
          _permit = await AiGenerationGuard.issuePermit();
          eta = Duration.zero;
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                  'Debug mod: reklam akisi hata verdi, reklam atlandi ve yorum dogrudan baslatildi.'),
            ),
          );
        } else {
          messenger.showSnackBar(SnackBar(content: Text(adFailedText)));
          return;
        }
      }
    } else {
      // Coin path: no waiting (coin, gerçek para değil)
      final ok = await AccessGate.ensureCoinsOnlyOrPaywall(
        context,
        coinCost: SkuCosts.coffeeFast,
      );
      if (!ok || !mounted) return;
      _permit = await AiGenerationGuard.issuePermit();
    }

    if (eta > Duration.zero) {
      try {
        final readyAt = DateTime.now().add(eta);
        final extras = <String, dynamic>{
          'typeHint': 'coffee',
          if (cup1 != null || cup2 != null || saucer != null)
            'imagePaths': [
              if (cup1 != null) cup1!.path,
              if (cup2 != null) cup2!.path,
              if (saucer != null) saucer!.path,
            ],
          // Generate and save to history even if user leaves the page
          'topic': _topic,
          'style': _style,
          if ((_permit ?? '').trim().isNotEmpty) 'permit': _permit,
          if (adUsed) 'adBoost': true,
          // streaming/local flags removed
        };
        final locale = Localizations.localeOf(context).languageCode;
        final id = await PendingReadingsService.schedule(
            type: 'coffee', readyAt: readyAt, extras: extras, locale: locale);
        _scheduledId = id;
        // Add placeholder to History: "Hazırlanıyor"
        try {
          final hc = context.read<HistoryController>();
          final title = AppLocalizations.of(context).t('coffee.title');
          final preparing = AppLocalizations.of(context).t('reading.preparing');
          await hc.upsert(HistoryEntry(
            id: id,
            type: 'coffee',
            title: title,
            text: preparing,
            createdAt: DateTime.now(),
          ));
        } catch (_) {}
      } catch (_) {}
    }

    // Her iki akışta da "gönderme" hissi için scanning overlay gösterelim.
    setState(() {
      scanning = true;
      _eta = eta;
    });
  }

  Future<void> _pickFor(String slot, ImageSource source) async {
    final x = await ImagePicker()
        .pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (x == null) return;
    setState(() {
      final f = File(x.path);
      if (slot == 'cup1') cup1 = f;
      if (slot == 'cup2') cup2 = f;
      if (slot == 'saucer') saucer = f;
    });
  }

  Future<String?> _chooseSlot() async {
    return await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121018),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.coffee),
              title: Text(AppLocalizations.of(context).t('coffee.modal.cup1')),
              onTap: () => Navigator.pop(context, 'cup1'),
            ),
            ListTile(
              leading: const Icon(Icons.coffee),
              title: Text(AppLocalizations.of(context).t('coffee.modal.cup2')),
              onTap: () => Navigator.pop(context, 'cup2'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_food_beverage_outlined),
              title:
                  Text(AppLocalizations.of(context).t('coffee.modal.saucer')),
              onTap: () => Navigator.pop(context, 'saucer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<ImageSource?> _chooseSource() async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121018),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: Builder(
                builder: (ctx) {
                  final t = AppLocalizations.of(ctx).t('action.from_gallery');
                  return Text(t != 'action.from_gallery' ? t : 'Galeriden');
                },
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Builder(
                builder: (ctx) {
                  final t = AppLocalizations.of(ctx).t('action.from_camera');
                  return Text(t != 'action.from_camera' ? t : 'Kameradan');
                },
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickForWithChooser(String slot) async {
    final source = await _chooseSource();
    if (source == null) return;
    await _pickFor(slot, source);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      // Kahve yorumu ekranında global yıldızlı arka planı gizle,
      // sadece eski coffee_premium_bg arka planını göster.
      backgroundColor: const Color(0xFF080311),
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(loc.t('coffee.title'))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CoffeeThumbSlot(
                        label:
                            AppLocalizations.of(context).t('coffee.modal.cup1'),
                        file: cup1,
                        onTap: () => _pickForWithChooser('cup1')),
                    const SizedBox(width: 8),
                    CoffeeThumbSlot(
                        label:
                            AppLocalizations.of(context).t('coffee.modal.cup2'),
                        file: cup2,
                        onTap: () => _pickForWithChooser('cup2')),
                    const SizedBox(width: 8),
                    CoffeeThumbSlot(
                        label: AppLocalizations.of(context)
                            .t('coffee.modal.saucer'),
                        file: saucer,
                        onTap: () => _pickForWithChooser('saucer')),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox.shrink(),
                    Wrap(
                      spacing: 8,
                      children: ['general', 'love', 'work', 'money', 'health']
                          .map((k) {
                        String label;
                        final loc = AppLocalizations.of(context);
                        switch (k) {
                          case 'love':
                            label = loc.t('coffee.topic.love') !=
                                    'coffee.topic.love'
                                ? loc.t('coffee.topic.love')
                                : 'Ask';
                            break;
                          case 'work':
                            label = loc.t('coffee.topic.work') !=
                                    'coffee.topic.work'
                                ? loc.t('coffee.topic.work')
                                : 'Is';
                            break;
                          case 'money':
                            label = loc.t('coffee.topic.money') !=
                                    'coffee.topic.money'
                                ? loc.t('coffee.topic.money')
                                : 'Para';
                            break;
                          case 'health':
                            label = loc.t('coffee.topic.health') !=
                                    'coffee.topic.health'
                                ? loc.t('coffee.topic.health')
                                : 'Saglik';
                            break;
                          default:
                            label = loc.t('coffee.topic.general') !=
                                    'coffee.topic.general'
                                ? loc.t('coffee.topic.general')
                                : 'Genel';
                        }
                        return ChoiceChip(
                          label: Text(label),
                          selected: _topic == k,
                          onSelected: (_) => setState(() => _topic = k),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon:
                          const Icon(Icons.monetization_on_outlined, size: 18),
                      onPressed: () async {
                        await _startReading(viaAd: false);
                      },
                      label: Consumer<EntitlementsController>(
                        builder: (_, ent, __) => Text(
                            'Coin ile Yorum Al (${SkuCosts.coffeeFast} coin) • Mevcut: ${ent.coins}'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: MystiqBackground(
        child: Stack(
          children: [
            if (scanning)
              ScanningOverlay(
                onDone: () {
                  if (!mounted) return;
                  setState(() => scanning = false);
                  final paths = [
                    if (cup1 != null) cup1!.path,
                    if (cup2 != null) cup2!.path,
                    if (saucer != null) saucer!.path,
                  ];
                  final eta = _eta ?? _defaultEta;
                  final extra = <String, dynamic>{
                    if (paths.isNotEmpty) 'imagePath': paths.first,
                    if (paths.isNotEmpty) 'imagePaths': paths,
                    'topic': _topic,
                    'style': _style,
                    if ((_permit ?? '').trim().isNotEmpty) 'permit': _permit,
                  };
                  if (eta > Duration.zero) {
                    extra.addAll({
                      'etaSeconds': eta.inSeconds,
                      'readyAt': DateTime.now().add(eta).toIso8601String(),
                      'generateAtReady': true,
                      if (_scheduledId != null) 'pendingId': _scheduledId,
                    });
                  }
                  context.push('/reading/result/coffee', extra: extra);
                },
              )
          ],
        ),
      ),
    );
  }
}
