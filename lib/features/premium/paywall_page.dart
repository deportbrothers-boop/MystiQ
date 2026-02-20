import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/widgets/starry_background.dart';
import '../../core/ads/rewarded_helper.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../core/i18n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// Bu projede gerçek para ile ödeme yoktur.
/// Coin yalnızca reklam izleyerek kazanılır.
class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ent = context.read<EntitlementsController>();
    return ChangeNotifierProvider.value(
      value: ent,
      child: const _EarnCoinsView(),
    );
  }
}

class _EarnCoinsView extends StatelessWidget {
  const _EarnCoinsView();

  @override
  Widget build(BuildContext context) {
    final ent = context.watch<EntitlementsController>();
    final loc = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: StarryBackground(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B0A0E), Color(0xFF121018)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Coin Kazan',
                  style: TextStyle(color: AppTheme.gold, fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121018),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.45), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.gold.withValues(alpha: 0.25),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.ondemand_video_outlined, color: AppTheme.gold),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bu uygulamada gerçek para ile ödeme yoktur. Coin yalnızca reklam izleyerek kazanılır.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Mevcut Coin: ${ent.coins}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.ondemand_video_outlined),
                      label: Text(loc.t('paywall.watch_ad')),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await RewardedAds.show(context: context);
                        if (ok && context.mounted) {
                          await ent.addCoins(10);
                          messenger.showSnackBar(SnackBar(content: Text(loc.t('paywall.ad_coin_added'))));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Reklam izleyerek coin biriktirebilir ve yorum alabilirsiniz.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                  child: Text(
                    'Bu içerik eğlence amaçlıdır. Kesinlik içermez.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
