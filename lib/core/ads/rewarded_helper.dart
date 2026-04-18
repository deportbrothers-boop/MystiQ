import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';
import 'dart:io';
import '../entitlements/entitlements_controller.dart';

class RewardedAds {
  // Production rewarded ad unit ids
  static const String _androidUnit = 'ca-app-pub-4678612524495888/4461067330';
  static const String _iosUnit = 'ca-app-pub-4678612524495888/8396442918';
  static EntitlementsController? _entitlements;

  static void init(EntitlementsController ent) {
    _entitlements = ent;
  }

  static Future<bool> show({required BuildContext context, String? adUnitId}) async {
    final entCtrl = RewardedAds._entitlements;
    if (entCtrl != null && entCtrl.isPremium) return true;
    final completer = Completer<bool>();
    bool retried = false;
    var earned = false;
    var impression = false;
    var showed = false;

    Future<void> loadOnce() async {
      await RewardedAd.load(
        adUnitId: adUnitId ?? (Platform.isIOS ? _iosUnit : _androidUnit),
        request: AdService.buildRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) async {
            debugPrint('[Rewarded] loaded: ${ad.adUnitId}');
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                showed = true;
                debugPrint('[Rewarded] showed');
              },
              onAdImpression: (ad) {
                impression = true;
                debugPrint('[Rewarded] impression');
              },
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('[Rewarded] dismissed (earned=$earned, impression=$impression)');
                ad.dispose();
                // Bazı cihazlarda `onUserEarnedReward` tetiklenmeyebiliyor;
                // reklam gerçekten gösterildiyse (showed/impression) akışı bloklamayalım.
                if (!completer.isCompleted) completer.complete(earned || impression || showed);
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                debugPrint('[Rewarded] show failed: $err');
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              earned = true;
              debugPrint('[Rewarded] user earned reward: ${reward.amount} ${reward.type}');
              if (!completer.isCompleted) completer.complete(true);
            });
          },
          onAdFailedToLoad: (LoadAdError error) async {
            debugPrint('[Rewarded] load failed: ${error.code} ${error.message}');
            if (!retried) {
              retried = true;
              await Future.delayed(const Duration(seconds: 2));
              try {
                await loadOnce();
                return;
              } catch (_) {}
            }
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    }

    try {
      await loadOnce();
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }

    // Güvenlik: callback hiç gelmezse akış sonsuza kalmasın.
    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => false,
    );
  }

  static Future<bool> showMultiple({
    required BuildContext context,
    required int count,
    String? key,
  }) async {
    final entCtrl = RewardedAds._entitlements;
    if (entCtrl != null && entCtrl.isPremium) return true;
    if (count <= 0) return true;
    for (var i = 0; i < count; i++) {
      final ok = await show(context: context);
      if (!ok) return false;
      if (key != null && key.trim().isNotEmpty) {
        try {
          await recordOneFor(key);
        } catch (_) {}
      }
    }
    return true;
  }

  // Daily limit helpers (limits kaldırıldı)
  static Future<int> remainingToday({int maxPerDay = 3}) async {
    return 9999;
  }

  static Future<void> recordOne() async {}


  static Future<int> remainingTodayFor(String key, {required int maxPerDay}) async {
    return 9999;
  }

  static Future<void> recordOneFor(String key) async {}
}
