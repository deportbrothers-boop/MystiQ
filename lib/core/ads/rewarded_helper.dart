import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RewardedAds {
  // Google test rewarded ad unit id
  static const String _testUnit = 'ca-app-pub-3940256099942544/5224354917';
  static const String _kYmd = 'ad_coin_ymd';
  static const String _kCount = 'ad_coin_count';

  static Future<bool> show({required BuildContext context, String? adUnitId}) async {
    final completer = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: adUnitId ?? _testUnit,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) async {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                ad.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              if (!completer.isCompleted) completer.complete(true);
            });
          },
          onAdFailedToLoad: (LoadAdError error) {
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
