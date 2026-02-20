import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/analytics/analytics.dart';
import '../../../core/readings/pending_readings_service_fixed.dart';
import '../../../common/widgets/scanning_overlay.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../core/access/ai_generation_guard.dart';

class PalmPage extends StatefulWidget {
  const PalmPage({super.key});
  @override
  State<PalmPage> createState() => _PalmPageState();
}

class _PalmPageState extends State<PalmPage> {
  File? image;
  bool scanning = false;
  bool _adUsed = false;
  String? _permit;

  double _goldAlpha = 0.35; // border color opacity
  double _goldStroke = 1.8; // border width
  int _starCount = 56; // background stars
  String _style = 'practical'; // 'practical' | 'spiritual' | 'analytical'

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source);
      if (x != null) setState(() => image = File(x.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('error.permission_denied'))),
      );
    }
  }

  Future<void> _chooseAndPick() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121018),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: Builder(builder: (ctx){
                final t = AppLocalizations.of(ctx).t('action.from_gallery');
                return Text(t != 'action.from_gallery' ? t : 'Galeriden');
              }),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Builder(builder: (ctx){
                final t = AppLocalizations.of(ctx).t('action.from_camera');
                return Text(t != 'action.from_camera' ? t : 'Kameradan');
              }),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (src != null) await _pick(src);
  }

  void _openGoldTuner() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121018),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppLocalizations.of(context).t('palm.tuner.alpha')}: ${_goldAlpha.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(value: _goldAlpha, min: 0, max: 1, divisions: 100, onChanged: (v) => setState(() => _goldAlpha = v)),
            const SizedBox(height: 6),
            Text(
              '${AppLocalizations.of(context).t('palm.tuner.stroke')}: ${_goldStroke.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(value: _goldStroke, min: 1, max: 4, divisions: 30, onChanged: (v) => setState(() => _goldStroke = v)),
            const SizedBox(height: 6),
            Text(
              '${AppLocalizations.of(context).t('palm.tuner.stars')}: $_starCount',
              style: const TextStyle(color: Colors.white70),
            ),
            Slider(value: _starCount.toDouble(), min: 24, max: 120, divisions: 24, onChanged: (v) => setState(() => _starCount = v.round())),
            Row(children: [
              TextButton(
                onPressed: () => setState(() {
                  _goldAlpha = 0.35;
                  _goldStroke = 1.8;
                  _starCount = 56;
                }),
                child: Text(AppLocalizations.of(context).t('action.reset')),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).t('action.close'))),
            ])
          ],
        ),
      ),
    );
  }

  Future<void> _startReading({bool forceAd = false}) async {
    if (image == null) return;
    await Analytics.log('reading_started', {'type': forceAd ? 'palm_ad' : 'palm'});
    if (!mounted) return;

    // Prevent starting a new reading if there is a pending one
    final nextAt = await PendingReadingsService.nextReadyAtForType('palm');
    if (nextAt != null && nextAt.isAfter(DateTime.now())) {
      if (!mounted) return;
      final left = nextAt.difference(DateTime.now()).inMinutes + 1;
      final msg = '${AppLocalizations.of(context).t('palm.title')} - bekleyen okuma var. Kalan: ~${left} dk';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final useAdFlow = forceAd;
    if (useAdFlow) {
      final remaining = await RewardedAds.remainingTodayFor('palm', maxPerDay: 1);
      if (remaining <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bugunluk el cizgisi yorumu reklam hakkin doldu.')),
        );
        return;
      }
      final okAd = await RewardedAds.showMultiple(context: context, count: 2, key: 'palm');
      if (!okAd || !mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reklam gosterilemedi. Tekrar deneyin.')),
          );
        }
        return;
      }
      if (!mounted) return;
      _adUsed = true;
      _permit = await AiGenerationGuard.issuePermit();
      setState(() => scanning = true);
      return;
    }

    final ok = await AccessGate.ensureCoinsOnlyOrPaywall(context, coinCost: SkuCosts.palmPremium);
    if (!ok) return;
    if (!mounted) return;
    _adUsed = false;
    _permit = await AiGenerationGuard.issuePermit();
    context.push('/reading/result/palm', extra: {
      'imagePath': image!.path,
      'style': _style,
      if ((_permit ?? '').trim().isNotEmpty) 'permit': _permit,
      // streaming/local flags removed
    });
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final displayCost = SkuCosts.palmPremium;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).t('palm.title')),
        actions: const [],
      ),
      body: Stack(children: [
        // Subtle background
        CustomPaint(painter: _PalmStarsPainter(goldAlpha: _goldAlpha, starCount: _starCount), size: Size.infinite),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 8),
            Expanded(
              child: GestureDetector(
                onTap: _chooseAndPick,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gold.withValues(alpha: (_goldAlpha.clamp(0, 1)).toDouble()), width: _goldStroke),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: image == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.pan_tool_outlined, size: 80, color: Colors.white70),
                                const SizedBox(height: 10),
                                Text(AppLocalizations.of(context).t('palm.add_photo_hint'), style: const TextStyle(color: Colors.white54)),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox.expand(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                child: Image.file(image!),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),            const SizedBox(height: 14),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.image, size: 18),
                  label: Text(AppLocalizations.of(context).t('action.from_gallery')),
                  onPressed: () => _pick(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.photo_camera, size: 18),
                  label: Text(AppLocalizations.of(context).t('action.from_camera')),
                  onPressed: () => _pick(ImageSource.camera),
                ),
              ),
            ]),


            const SizedBox(height: 10),
            SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('2 Reklam izle'),
                      onPressed: image == null ? null : () => _startReading(forceAd: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: image == null ? null : () => _startReading(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppLocalizations.of(context).t('palm.cta_start')),
                          const SizedBox(width: 8),
                          const Icon(Icons.monetization_on_outlined, size: 16),
                          const SizedBox(width: 2),
                          Text('$displayCost'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),

        if (scanning)
          ScanningOverlay(
            onDone: () async {
              if (!mounted) return;
              setState(() => scanning = false);
              // Planlı üretim: geri sayım ve reklamla hızlandırma için pending oluştur
              final eta = const Duration(minutes: 5);
              final readyAt = DateTime.now().add(eta);
              String? pendingId;
              try {
                final locale = Localizations.localeOf(context).languageCode;
                pendingId = await PendingReadingsService.schedule(
                  type: 'palm',
                  readyAt: readyAt,
                  extras: {
                    'imagePath': image!.path,
                    'style': _style,
                    if ((_permit ?? '').trim().isNotEmpty) 'permit': _permit,
                    if (_adUsed) 'adBoost': true,
                  },
                  locale: locale,
                );
              } catch (_) {}
              if (!mounted) return;
              context.push('/reading/result/palm', extra: {
                'imagePath': image!.path,
                'style': _style,
                if ((_permit ?? '').trim().isNotEmpty) 'permit': _permit,
                if (_adUsed) 'adBoost': true,
                'sessionId': DateTime.now().millisecondsSinceEpoch,
                'etaSeconds': eta.inSeconds,
                'readyAt': readyAt.toIso8601String(),
                'generateAtReady': true,
                // streaming/local flags removed
                if (pendingId != null) 'pendingId': pendingId,
              });
            },
          ),
      ]),
    );
  }
}

class _PalmStarsPainter extends CustomPainter {
  final double goldAlpha;
  final int starCount;
  const _PalmStarsPainter({required this.goldAlpha, required this.starCount});
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const RadialGradient(colors: [Color(0x332A1B4A), Colors.transparent], radius: 0.6)
          .createShader(Rect.fromCircle(center: const Offset(80, 60), radius: 160));
    canvas.drawRect(Offset.zero & size, bg);

    final violet = Paint()..color = const Color(0xFF9B79F7).withValues(alpha: 0.18);
    final gold = Paint()..color = const Color(0xFFFFC857).withValues(alpha: (goldAlpha * 0.6).clamp(0.08, 0.6));
    for (int i = 0; i < starCount; i++) {
      final dx = (i * 71 % size.width).toDouble();
      final dy = (i * 119 % size.height).toDouble();
      final r = (i % 7 == 0) ? 1.9 : 1.2;
      canvas.drawCircle(Offset(dx, dy), r, i.isEven ? violet : gold);
    }
  }

  @override
  bool shouldRepaint(covariant _PalmStarsPainter old) => old.goldAlpha != goldAlpha || old.starCount != starCount;
}












