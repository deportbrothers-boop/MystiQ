import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/history/history_controller.dart';
import '../entitlements/entitlements_controller.dart';

class RewardsController with ChangeNotifier {
  static const _weeklyKey = 'weeklyClaimWeek';
  static const _streakCountKey = 'streak_count';
  static const _streakLastLoginKey = 'streak_last_login';
  static const _streakRewardedWeekKey = 'streak_rewarded_week';

  int? _weeklyWeek;
  int _streakCount = 0;
  String? _streakLastLogin;
  String? _streakRewardedWeek;

  int get streakCount => _streakCount;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _weeklyWeek = sp.getInt(_weeklyKey);
    _streakCount = sp.getInt(_streakCountKey) ?? 0;
    _streakLastLogin = sp.getString(_streakLastLoginKey);
    _streakRewardedWeek = sp.getString(_streakRewardedWeekKey);
    notifyListeners();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _weekStr(DateTime d) {
    final weekOfYear =
        ((d.difference(DateTime(d.year, 1, 1)).inDays) / 7).floor();
    return '${d.year}-W$weekOfYear';
  }

  int _weekOfYear(DateTime d) {
    final firstDay = DateTime(d.year, 1, 1);
    return ((d.difference(firstDay).inDays + firstDay.weekday) / 7).floor();
  }

  // Günlük giriş streak'ini kontrol et ve kaydet
  // Returns: {streak: int, rewardEarned: bool, alreadyCheckedIn: bool}
  Future<Map<String, dynamic>> recordDailyLogin(
      EntitlementsController ent) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = _ymd(now);

    // Bugün zaten giriş yapıldıysa değişiklik yok
    if (_streakLastLogin == todayStr) {
      return {
        'streak': _streakCount,
        'rewardEarned': false,
        'alreadyCheckedIn': true,
      };
    }

    final yesterday = _ymd(now.subtract(const Duration(days: 1)));

    int newStreak;
    if (_streakLastLogin == yesterday) {
      newStreak = _streakCount + 1;
    } else {
      newStreak = 1;
    }

    _streakLastLogin = todayStr;
    _streakCount = newStreak;
    await sp.setString(_streakLastLoginKey, todayStr);
    await sp.setInt(_streakCountKey, newStreak);

    // 7. günde ödül ver
    bool rewardEarned = false;
    final thisWeekKey = _weekStr(now);
    if (newStreak >= 7 && _streakRewardedWeek != thisWeekKey) {
      _streakRewardedWeek = thisWeekKey;
      await sp.setString(_streakRewardedWeekKey, thisWeekKey);
      // 30 coin ödülü
      await ent.addCoins(30);
      // Streak sıfırla
      _streakCount = 0;
      await sp.setInt(_streakCountKey, 0);
      rewardEarned = true;
    }

    notifyListeners();
    return {
      'streak': newStreak,
      'rewardEarned': rewardEarned,
      'alreadyCheckedIn': false,
    };
  }

  bool checkedInToday() {
    final todayStr = _ymd(DateTime.now());
    return _streakLastLogin == todayStr;
  }

  // Haftalık ödül (3 yorum = 1 bilet)
  Future<bool> claimWeekly(
      EntitlementsController ent, HistoryController hist) async {
    final now = DateTime.now();
    final week = _weekOfYear(now);
    if (_weeklyWeek == week) return false;
    final since = now.subtract(const Duration(days: 7));
    final reads =
        hist.items.where((e) => e.createdAt.isAfter(since)).length;
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
    final reads =
        hist.items.where((e) => e.createdAt.isAfter(since)).length;
    return reads >= 3;
  }
}