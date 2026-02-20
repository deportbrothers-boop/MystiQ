import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/ai_generation_guard.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/entitlements/entitlements_controller.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../profile/profile_controller.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';

class AstroPage extends StatefulWidget {
  const AstroPage({super.key});
  @override
  State<AstroPage> createState() => _AstroPageState();
}

class _AstroPageState extends State<AstroPage> {
  String? text;
  StreamSubscription<String>? _sub;
  Timer? _fallbackTimer;
  final bool _streaming = false; // kept for compatibility
  final bool _didComplete = false; // kept for compatibility
  String _style = 'practical'; // 'practical' | 'spiritual'
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _startAstro({required bool viaAd}) async {
    if (!mounted) return;
    setState(() => _busy = true);
    String permit = '';
    try {
      const isPremium = false;

      if (!isPremium) {
        if (viaAd) {
          final remaining = await RewardedAds.remainingTodayFor('astro', maxPerDay: 1);
          if (remaining <= 0) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bugünlük astroloji reklam hakkın doldu.')),
            );
            return;
          }
          final okAd = await RewardedAds.showMultiple(context: context, count: 2, key: 'astro');
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
          // ads already recorded via showMultiple
        } else {
          final ok = await AccessGate.ensureCoinsOnlyOrPaywall(context, coinCost: SkuCosts.astro);
          if (!ok || !mounted) return;
        }
      }

      final profile = context.read<ProfileController>().profile;
      final locale = Localizations.localeOf(context).languageCode;
      permit = await AiGenerationGuard.issuePermit();
      late final String generated;
      try {
        generated = await AiService.generate(
          type: 'astro',
          profile: profile,
          extras: {'style': _style, 'permit': permit},
          locale: locale,
        );
      } on AiGenerationGuardException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu işlem için önce erişim alınması gerekiyor.')),
        );
        return;
      }
      final hc = context.read<HistoryController>();
      final entry = HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'astro',
        title: AppLocalizations.of(context).t('astro.title'),
        text: generated,
        createdAt: DateTime.now(),
      );
      await hc.add(entry);
      if (!mounted) return;
      context.push('/reading/result/astro', extra: entry);
    } catch (_) {
      if (!mounted) return;
      // If generation failed before consuming the permit, allow Result page to try once.
      if (permit.trim().isNotEmpty) {
        context.push('/reading/result/astro', extra: {'style': _style, 'permit': permit});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu. Lütfen tekrar deneyin.')),
        );
      }
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
              Text('${loc.t('astro.zodiac')}${profile.zodiac.isEmpty ? '-' : profile.zodiac}'),
              const SizedBox(height: 12),
              Expanded(
                child: text != null
                    ? SingleChildScrollView(child: Text(text!))
                    : Center(child: Text(loc.t('astro.empty_hint'))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : () => _startAstro(viaAd: true),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: Builder(builder: (ctx) {
                        final t = AppLocalizations.of(ctx).t('astro.entry.watch_and_read');
                        return Text(t != 'astro.entry.watch_and_read' ? t : '2 Reklam izle, Yorum Al');
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _startAstro(viaAd: false),
                      icon: const Icon(Icons.monetization_on_outlined, size: 18),
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
