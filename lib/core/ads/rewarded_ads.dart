import 'package:flutter/material.dart';
import 'rewarded_helper.dart' as helper;
import '../entitlements/entitlements_controller.dart';

class RewardedAds {
  static EntitlementsController? _entitlements;
  static void init(EntitlementsController ent) { _entitlements = ent; }

  static Future<bool> show({required BuildContext context, String? adUnitId}) async {
    if (_entitlements?.isPremium == true) return true;
    return helper.RewardedAds.show(context: context, adUnitId: adUnitId);
  }

  static Future<bool> showMultiple({
    required BuildContext context,
    required int count,
    String? key,
  }) async {
    if (_entitlements?.isPremium == true) return true;
    return helper.RewardedAds.showMultiple(
      context: context,
      count: count,
      key: key,
    );
  }

  static Future<int> remainingToday({int maxPerDay = 3}) {
    return helper.RewardedAds.remainingToday(maxPerDay: maxPerDay);
  }

  static Future<void> recordOne() {
    return helper.RewardedAds.recordOne();
  }

  static Future<int> remainingTodayFor(String key, {required int maxPerDay}) {
    return helper.RewardedAds.remainingTodayFor(key, maxPerDay: maxPerDay);
  }

  static Future<void> recordOneFor(String key) {
    return helper.RewardedAds.recordOneFor(key);
  }
}
