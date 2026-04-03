import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/access/access_gate.dart';
import '../../../core/access/ai_generation_guard.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/readings/pending_readings_service_fixed.dart';
import '../../../core/readings/reading_timing.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import '../../profile/profile_controller.dart';

class AstroPage extends StatefulWidget {
  const AstroPage({super.key});

  @override
  State<AstroPage> createState() => _AstroPageState();
}

class _AstroPageState extends State<AstroPage> {
  final String _style = 'practical';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _redirectToPendingIfAny());
  }

  Future<void> _redirectToPendingIfAny() async {
    try {
      final item = await PendingReadingsService.firstPendingOfType('astro');
      if (!mounted || item == null) return;
      final readyAt = DateTime.tryParse((item['readyAt'] as String?) ?? '');
      if (readyAt == null) return;
      final pendingId = item['id']?.toString();
      final extras = (item['extras'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      context.push('/reading/result/astro', extra: {
        ...extras,
        'etaSeconds':
            readyAt.difference(DateTime.now()).inSeconds.clamp(0, 86400),
        'readyAt': readyAt.toIso8601String(),
        'generateAtReady': true,
        if (pendingId != null && pendingId.isNotEmpty) 'pendingId': pendingId,
      });
    } catch (_) {}
  }

  Future<void> _startAstro({required bool viaAd}) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      if (viaAd) {
        final remaining =
            await RewardedAds.remainingTodayFor('astro', maxPerDay: 1);
        if (remaining <= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Bugünlük astroloji reklam hakkın doldu.')),
          );
          return;
        }
        final okAd = await RewardedAds.showMultiple(
            context: context, count: 2, key: 'astro');
        if (!okAd || !mounted) {
          final loc = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                loc.t('tarot.fast.ad_failed') != 'tarot.fast.ad_failed'
                    ? loc.t('tarot.fast.ad_failed')
                    : 'Reklam gösterilemedi. Tekrar deneyin.',
              ),
            ),
          );
          return;
        }
      } else {
        final ok = await AccessGate.ensureCoinsOnlyOrPaywall(context,
            coinCost: SkuCosts.astro);
        if (!ok || !mounted) return;
      }

      final permit = await AiGenerationGuard.issuePermit();
      final eta = ReadingTiming.initialWaitFor('astro');
      final readyAt = DateTime.now().add(eta);
      String? pendingId;
      try {
        final locale = Localizations.localeOf(context).languageCode;
        final extras = <String, dynamic>{
          'style': _style,
          'permit': permit,
          if (viaAd) 'adBoost': true,
        };
        pendingId = await PendingReadingsService.schedule(
          type: 'astro',
          readyAt: readyAt,
          extras: extras,
          locale: locale,
        );
        try {
          final hc = context.read<HistoryController>();
          if (pendingId != null) {
            await hc.upsert(HistoryEntry(
              id: pendingId,
              type: 'astro',
              title: AppLocalizations.of(context).t('astro.title'),
              text: AppLocalizations.of(context).t('reading.preparing'),
              createdAt: DateTime.now(),
            ));
          }
        } catch (_) {}
      } catch (_) {}

      if (!mounted) return;
      context.push('/reading/result/astro', extra: {
        'style': _style,
        'permit': permit,
        if (viaAd) 'adBoost': true,
        'etaSeconds': eta.inSeconds,
        'readyAt': readyAt.toIso8601String(),
        'generateAtReady': true,
        if (pendingId != null) 'pendingId': pendingId,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('astro.title'))),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${loc.t('astro.zodiac')}${profile.zodiac.isEmpty ? '-' : profile.zodiac}'),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: Text(
                    loc.t('astro.empty_hint'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : () => _startAstro(viaAd: true),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: Builder(
                        builder: (ctx) {
                          final t = AppLocalizations.of(ctx)
                              .t('astro.entry.watch_and_read');
                          return Text(t != 'astro.entry.watch_and_read'
                              ? t
                              : '2 Reklam izle, Yorum Al');
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _startAstro(viaAd: false),
                      icon:
                          const Icon(Icons.monetization_on_outlined, size: 18),
                      label: Text('Coin ile Al (${SkuCosts.astro})'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
