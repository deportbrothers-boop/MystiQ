import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/mystiq_background.dart';
import '../../../common/widgets/scanning_overlay.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/entitlements/entitlements_controller.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/readings/pending_readings_service.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import 'package:mystiq/features/readings/coffee/_thumb_slot.dart';

class CoffeePage extends StatefulWidget {
  const CoffeePage({super.key});
  @override
  State<CoffeePage> createState() => _CoffeePageState();
}

class _CoffeePageState extends State<CoffeePage> with SingleTickerProviderStateMixin {
  File? cup1;
  File? cup2;
  File? saucer;
  bool scanning = false;
  late final AnimationController _pulse;
  String? _scheduledId;
  Duration? _eta; // last selected ETA (10m or 5m)
  bool _adUsed = false;
  String _topic = 'general';
  String _style = 'practical'; // 'practical' | 'spiritual' | 'analytical'

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    // If a pending coffee exists, redirect directly to Result with countdown
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final item = await PendingReadingsService.firstPendingOfType('coffee');
        if (!mounted || item == null) return;
        final readyAt = DateTime.tryParse((item['readyAt'] as String?) ?? '');
        if (readyAt == null) return;
        final extras = (item['extras'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final paths = (extras['imagePaths'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
        if (!mounted) return;
        context.push('/reading/result/coffee', extra: {
          if (paths.isNotEmpty) 'imagePaths': paths,
          'etaSeconds': readyAt.difference(DateTime.now()).inSeconds.clamp(0, 86400),
          'readyAt': readyAt.toIso8601String(),
          'generateAtReady': true,
          'noStream': true,
          'forceLocal': true,
        });
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _startReading({bool forceAd = false}) async {
    final selectedCount = [cup1, cup2, saucer].where((e) => e != null).length;
    if (selectedCount == 0) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('coffee.snackbar.missing'))),
      );
      return;
    }

    await Analytics.log('reading_started', {'type': 'coffee'});
    if (!mounted) return;

    // Coins-only gate: reklam yolunda atla, normal akışta uygula
    if (!forceAd) {
      final okCoins = await AccessGate.ensureCoinsOnlyOrPaywall(
        context,
        coinCost: SkuCosts.coffeeFast,
      );
      if (!okCoins || !mounted) return;
    }

    // ETA: varsayılan 10dk. İlk reklam hızlandırmaz; sadece hak tanır.
    Duration eta = const Duration(minutes: 10);
    bool adUsed = false;
    if (forceAd) {
      try {
        final ok = await RewardedAds.show(context: context);
        if (!mounted) return;
        if (ok) {
          adUsed = true;
          try { await RewardedAds.recordOne(); } catch (_) {}
          // İlk reklamdan sonra bekleme 10 dk kalır; hızlandırma sonuç ekranında yapılır.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              AppLocalizations.of(context).t('coffee.entry.ad_ok') != 'coffee.entry.ad_ok'
                  ? AppLocalizations.of(context).t('coffee.entry.ad_ok')
                  : 'Reklam izlendi. Sonuç yaklaşık 10 dk içinde hazır. Hızlandırmak için sonuç ekranında reklam izleyebilirsiniz.'
            )),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
              AppLocalizations.of(context).t('coffee.fast.ad_failed') != 'coffee.fast.ad_failed'
                  ? AppLocalizations.of(context).t('coffee.fast.ad_failed')
                  : 'Reklam gosterilemedi. Normal hizda devam ediliyor (10 dk).'
            )),
          );
        }
      } catch (_) {}
    } else {
      // no-op: keep eta 10 dk
    }

    try {
      final readyAt = DateTime.now().add(eta);
      final extras = <String, dynamic>{
        if (cup1 != null || cup2 != null || saucer != null)
          'imagePaths': [
            if (cup1 != null) cup1!.path,
            if (cup2 != null) cup2!.path,
            if (saucer != null) saucer!.path,
          ],
        // Generate and save to history even if user leaves the page
        'topic': _topic,
        'style': _style,
        if (adUsed) 'adBoost': true,
        'forceLocal': true,
      };
      final locale = Localizations.localeOf(context).languageCode;
      final id = await PendingReadingsService.schedule(type: 'coffee', readyAt: readyAt, extras: extras, locale: locale);
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
    setState(() { scanning = true; _eta = eta; _adUsed = adUsed; });
  }

  Future<void> _pickFor(String slot, ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source);
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
              title: Text(AppLocalizations.of(context).t('coffee.modal.saucer')),
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
                    CoffeeThumbSlot(label: AppLocalizations.of(context).t('coffee.modal.cup1'), file: cup1, onTap: () => _pickForWithChooser('cup1')),
                    const SizedBox(width: 8),
                    CoffeeThumbSlot(label: AppLocalizations.of(context).t('coffee.modal.cup2'), file: cup2, onTap: () => _pickForWithChooser('cup2')),
                    const SizedBox(width: 8),
                    CoffeeThumbSlot(label: AppLocalizations.of(context).t('coffee.modal.saucer'), file: saucer, onTap: () => _pickForWithChooser('saucer')),
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
                      children: ['general','love','work','money','health'].map((k) {
                        String label;
                        final loc = AppLocalizations.of(context);
                        switch (k) {
                          case 'love': label = loc.t('coffee.topic.love') != 'coffee.topic.love' ? loc.t('coffee.topic.love') : 'Ask'; break;
                          case 'work': label = loc.t('coffee.topic.work') != 'coffee.topic.work' ? loc.t('coffee.topic.work') : 'Is'; break;
                          case 'money': label = loc.t('coffee.topic.money') != 'coffee.topic.money' ? loc.t('coffee.topic.money') : 'Para'; break;
                          case 'health': label = loc.t('coffee.topic.health') != 'coffee.topic.health' ? loc.t('coffee.topic.health') : 'Saglik'; break;
                          default: label = loc.t('coffee.topic.general') != 'coffee.topic.general' ? loc.t('coffee.topic.general') : 'Genel';
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
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide.none,
                    ),
                    icon: const Icon(Icons.image, size: 18),
                    label: Text(loc.t('coffee.add_photo')),
                    onPressed: () async {
                      final slot = await _chooseSlot();
                      if (slot == null) return;
                      final source = await _chooseSource();
                      if (source == null) return;
                      await _pickFor(slot, source);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        // Entry modal: "Reklam izle, Fal Bak" vs "Premium'a geç"
                        final choice = await showModalBottomSheet<String>(
                          context: context,
                          showDragHandle: true,
                          backgroundColor: const Color(0xFF121018),
                          builder: (_) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).t('coffee.entry.title') != 'coffee.entry.title'
                                        ? AppLocalizations.of(context).t('coffee.entry.title')
                                        : 'Devam etmeyi seçin',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.play_circle_outline, size: 18),
                                        onPressed: () => Navigator.pop(context, 'ad'),
                                        label: Text(
                                          AppLocalizations.of(context).t('coffee.entry.watch_and_read') != 'coffee.entry.watch_and_read'
                                              ? AppLocalizations.of(context).t('coffee.entry.watch_and_read')
                                              : 'Reklam izle, Fal Bak',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context, 'coin'),
                                        child: Text(
                                          AppLocalizations.of(context).t('coffee.entry.coin') != 'coffee.entry.coin'
                                              ? AppLocalizations.of(context).t('coffee.entry.coin')
                                              : 'Coin ile Fal Bak',
                                        ),
                                      ),
                                    ),
                                  ])
                                ],
                              ),
                            ),
                          ),
                        );
                        if (!mounted) return;
                        if (choice == 'ad') {
                          await _startReading(forceAd: true);
                        } else if (choice == 'coin') {
                          await _startReading();
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(loc.t('coffee.cta') != 'coffee.cta' ? loc.t('coffee.cta') : 'Fal Bak'),
                          const SizedBox(width: 8),
                          const Icon(Icons.monetization_on_outlined, size: 16),
                          const SizedBox(width: 2),
                          Text('${SkuCosts.coffeeFast}'),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: (loc.t('coins.reason.coffee') != 'coins.reason.coffee')
                                ? loc.t('coins.reason.coffee')
                                : 'Goruntu analizi ve AI uretimi coin gerektirir.',
                            child: const Icon(Icons.info_outline, size: 16),
                          )
                        ],
                      )
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
                  context.push('/reading/result/coffee', extra: {
                    if (paths.isNotEmpty) 'imagePath': paths.first,
                    if (paths.isNotEmpty) 'imagePaths': paths,
                    // Always show countdown (10 dk veya reklam ile 5 dk)
                    'etaSeconds': (_eta ?? const Duration(minutes: 10)).inSeconds,
                    'readyAt': DateTime.now().add(_eta ?? const Duration(minutes: 10)).toIso8601String(),
                    'generateAtReady': true,
                    'topic': _topic,
                    'style': _style,
                    'noStream': true,
                    'forceLocal': true,
                    if (_scheduledId != null) 'pendingId': _scheduledId,
                  });
                },
              )
          ],
        ),
      ),
    );
  }
}
