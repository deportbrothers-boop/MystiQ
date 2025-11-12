import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class RewardedAds {
  // Google test rewarded ad unit id
  static const String _androidUnit = 'ca-app-pub-4678612524495888/4461067330';
  static const String _iosUnit = 'ca-app-pub-4678612524495888/8396442918';
  static const String _kYmd = 'ad_coin_ymd';
  static const String _kCount = 'ad_coin_count';

  static Future<bool> show({required BuildContext context, String? adUnitId}) async {
    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: adUnitId ?? (Platform.isIOS ? _iosUnit : _androidUnit),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) async {
            debugPrint('[Rewarded] loaded: ' + ad.adUnitId);
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                debugPrint('[Rewarded] show failed: ' + err.toString());
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              debugPrint('[Rewarded] user earned reward: ' + reward.amount.toString() + ' ' + reward.type);
              if (!completer.isCompleted) completer.complete(true);
            });
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('[Rewarded] load failed: ${error.code} ${error.message}');
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  // Daily limit helpers
  static Future<int> remainingToday({int maxPerDay = 3}) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final ymd = '${now.year}-${now.month}-${now.day}';
    final savedYmd = sp.getString(_kYmd);
    int count = sp.getInt(_kCount) ?? 0;
    if (savedYmd != ymd) {
      count = 0;
      await sp.setString(_kYmd, ymd);
      await sp.setInt(_kCount, 0);
    }
    final remaining = maxPerDay - count;
    return remaining < 0 ? 0 : remaining;
  }

  static Future<void> recordOne() async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final ymd = '${now.year}-${now.month}-${now.day}';
    final savedYmd = sp.getString(_kYmd);
    if (savedYmd != ymd) {
      await sp.setString(_kYmd, ymd);
      await sp.setInt(_kCount, 1);
    } else {
      final count = (sp.getInt(_kCount) ?? 0) + 1;
      await sp.setInt(_kCount, count);
    }
  }
}

