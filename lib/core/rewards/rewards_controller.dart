import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/history/history_controller.dart';
import '../entitlements/entitlements_controller.dart';

class RewardsController with ChangeNotifier {
  static const _dailyKey = 'dailyClaimYMD';
  static const _weeklyKey = 'weeklyClaimWeek';

  String? _dailyYmd;
  int? _weeklyWeek;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _dailyYmd = sp.getString(_dailyKey);
    _weeklyWeek = sp.getInt(_weeklyKey);
    notifyListeners();
  }

  String _ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';
  int _weekOfYear(DateTime d) {
    final firstDay = DateTime(d.year, 1, 1);
    return ((d.difference(firstDay).inDays + firstDay.weekday) / 7).floor();
  }

  Future<bool> claimDaily(EntitlementsController ent) async {
    final today = _ymd(DateTime.now());
    if (_dailyYmd == today) return false;
    final sp = await SharedPreferences.getInstance();
    await ent.grantDailyLoginBonus();
    _dailyYmd = today;
    await sp.setString(_dailyKey, today);
    notifyListeners();
    return true;
  }

  bool canClaimDaily() => _dailyYmd != _ymd(DateTime.now());

  Future<bool> claimWeekly(EntitlementsController ent, HistoryController hist) async {
    final now = DateTime.now();
    final week = _weekOfYear(now);
    if (_weeklyWeek == week) return false;
    final since = now.subtract(const Duration(days: 7));
    final reads = hist.items.where((e) => e.createdAt.isAfter(since)).length;
    if (reads < 3) return false;
    final sp = await SharedPreferences.getInstance();
    await ent.grantCampaignAfterThreeReads(reads);
    _weeklyWeek = week;
    await sp.setInt(_weeklyKey, week);
    notifyListeners();
    return true;
  }

  bool canClaimWeekly(HistoryController hist) {
    final now = DateTime.now();
    final week = _weekOfYear(now);
    if (_weeklyWeek == week) return false;
    final since = now.subtract(const Duration(days: 7));
    final reads = hist.items.where((e) => e.createdAt.isAfter(since)).length;
    return reads >= 3;
  }
}

