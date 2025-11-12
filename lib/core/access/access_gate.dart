import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../entitlements/entitlements_controller.dart';

class AccessGate {
  static Future<bool> ensureAccessOrPaywall(
    BuildContext context, {
    required String sku,
    required int coinCost,
  }) async {
    final ent = context.read<EntitlementsController>();
    final ok = await ent.tryConsumeForReading(coinCost: coinCost);
    if (ok) return true;
    // Production: block navigation and show paywall
    _showPaywallSheet(context);
    return false;
  }

  // Forces coin spending; ignores first-free, tickets and premium for this action
  static Future<bool> ensureCoinsOnlyOrPaywall(
    BuildContext context, {
    required int coinCost,
  }) async {
    final ent = context.read<EntitlementsController>();
    final ok = await ent.tryConsumeForReadingCoinsOnly(coinCost: coinCost);
    if (ok) return true;
    // Production: block navigation and show paywall
    _showPaywallSheet(context);
    return false;
  }

  static void _showPaywallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121018),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).t('access.paywall.title'), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).t('access.paywall.prompt')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { Navigator.pop(context); context.push('/paywall'); },
                      child: Text(AppLocalizations.of(context).t('access.buy_coins')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { Navigator.pop(context); context.push('/paywall'); },
                      child: Text(AppLocalizations.of(context).t('access.go_premium')),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}


