import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EntitlementsController with ChangeNotifier {
  static const _kPremiumSku = 'premiumSku';
  static const _kPremiumUntil = 'premiumUntil';
  static const _kCoins = 'coins';
  static const _kFirstFreeUsed = 'firstFreeUsed';

  String? premiumSku;
  DateTime? premiumUntil;
  int coins = 0;
  bool firstFreeUsed = false;
  int energy = 70; // 0..100
  int tickets = 0; // free reading tickets (e.g., campaign)
  String? _energyYmd;
  String? lastUnlockMethod; // 'coins' | 'premium' | 'first_free' | 'ticket'
  int _updatedAtMs = 0; // local last-change marker (ms since epoch)

  bool get isPremium =>
      premiumSku == 'lifetime.mystic_plus' ||
      (premiumUntil != null && premiumUntil!.isAfter(DateTime.now()));

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    premiumSku = sp.getString(_kPremiumSku);
    final untilStr = sp.getString(_kPremiumUntil);
    if (untilStr != null) premiumUntil = DateTime.tryParse(untilStr);
    coins = sp.getInt(_kCoins) ?? 0;
    firstFreeUsed = sp.getBool(_kFirstFreeUsed) ?? false;
    energy = sp.getInt('energy') ?? 70;
    tickets = sp.getInt('tickets') ?? 0;
    _energyYmd = sp.getString('energyYmd');
    _updatedAtMs = sp.getInt('ent_updatedAtMs') ?? 0;
    notifyListeners();

    // Try remote -> local sync (if logged in)
    try {
      await _syncFromRemote();
    } catch (_) {
      // ignore remote failures to avoid blocking app
    }
  }

  Future<void> _persist({bool skipRemote = false}) async {
    final sp = await SharedPreferences.getInstance();
    // bump local updatedAt marker
    _updatedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (premiumSku != null) await sp.setString(_kPremiumSku, premiumSku!);
    if (premiumUntil != null) {
      await sp.setString(_kPremiumUntil, premiumUntil!.toIso8601String());
    }
    await sp.setInt(_kCoins, coins);
    await sp.setBool(_kFirstFreeUsed, firstFreeUsed);
    await sp.setInt('energy', energy);
    await sp.setInt('tickets', tickets);
    if (_energyYmd != null) await sp.setString('energyYmd', _energyYmd!);
    await sp.setInt('ent_updatedAtMs', _updatedAtMs);

    if (!skipRemote) {
      try { await _persistRemote(); } catch (_) {}
    }
  }

  Future<void> _persistRemote() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('entitlements');
    await ref.set({
      'coins': coins,
      'premiumSku': premiumSku,
      'premiumUntil': premiumUntil?.toIso8601String(),
      'firstFreeUsed': firstFreeUsed,
      'tickets': tickets,
      'energy': energy,
      'updatedAt': FieldValue.serverTimestamp(), // server time
      'clientUpdatedAtMs': _updatedAtMs,
    }, SetOptions(merge: true));
  }

  Future<void> _syncFromRemote() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('entitlements');
    final snap = await ref.get();
    if (!snap.exists) {
      // initialize remote with current local
      await _persistRemote();
      return;
    }
    final data = snap.data();
    if (data == null) return;
    try {
      final remoteServerTs = data['updatedAt'];
      final remoteServerMs = remoteServerTs is Timestamp ? remoteServerTs.millisecondsSinceEpoch : 0;
      final remoteClientMs = (data['clientUpdatedAtMs'] is num) ? (data['clientUpdatedAtMs'] as num).toInt() : 0;
      final remoteMs = remoteServerMs > 0 ? remoteServerMs : remoteClientMs;

      if (remoteMs >= _updatedAtMs) {
        // merge field-by-field (prefer stronger state)
        final rCoins = (data['coins'] as num?)?.toInt();
        final rTickets = (data['tickets'] as num?)?.toInt();
        final rEnergy = (data['energy'] as num?)?.toInt();
        final rFirstFree = data['firstFreeUsed'] as bool?;
        final rSku = data['premiumSku'] as String?;
        DateTime? rUntil;
        final pu = data['premiumUntil'];
        if (pu is String) {
          rUntil = DateTime.tryParse(pu);
        } else if (pu is Timestamp) {
          rUntil = pu.toDate();
        }

        // coins: take max
        if (rCoins != null) coins = coins > rCoins ? coins : rCoins;
        // tickets: take max
        if (rTickets != null) tickets = tickets > rTickets ? tickets : rTickets;
        // energy: take max (avoid decreasing UX)
        if (rEnergy != null) energy = energy > rEnergy ? energy : rEnergy;
        // firstFreeUsed: if either true => true
        if (rFirstFree == true || firstFreeUsed == true) firstFreeUsed = true;
        // premium: lifetime wins; else later expiry wins
        final isLocalLifetime = premiumSku == 'lifetime.mystic_plus';
        final isRemoteLifetime = rSku == 'lifetime.mystic_plus';
        if (isRemoteLifetime || (!isLocalLifetime && (rUntil != null && (premiumUntil == null || rUntil.isAfter(premiumUntil!))))) {
          premiumSku = rSku ?? premiumSku;
          premiumUntil = isRemoteLifetime ? null : (rUntil ?? premiumUntil);
        }

        _updatedAtMs = remoteMs;
        final sp = await SharedPreferences.getInstance();
        await sp.setInt('ent_updatedAtMs', _updatedAtMs);
        // persist merged locally and push upstream to unify state
        await _persist(skipRemote: false);
        notifyListeners();
      } else if (remoteMs < _updatedAtMs) {
        // push local as authoritative
        await _persistRemote();
      } else {
        // equal, do nothing
      }
    } catch (_) {
      // ignore parse errors
    }
  }

  Future<void> grantFromSku(String sku) async {
    // Subscriptions / lifetime
    if (sku == 'sub.premium.monthly') {
      premiumSku = sku;
      premiumUntil = DateTime.now().add(const Duration(days: 30));
    } else if (sku == 'sub.premium.quarterly') {
      premiumSku = sku;
      premiumUntil = DateTime.now().add(const Duration(days: 90));
    } else if (sku == 'sub.premium.yearly') {
      premiumSku = sku;
      premiumUntil = DateTime.now().add(const Duration(days: 365));
    } else if (sku == 'lifetime.mystic_plus') {
      premiumSku = sku;
      premiumUntil = null;
    }

    // Coins
    else if (sku == 'coin.100') {
      coins += 100;
    } else if (sku == 'coin.500') {
      coins += 550; // +50 bonus
    } else if (sku == 'coin.1200') {
      coins += 1400; // +200 bonus
    } else if (sku == 'coin.3000') {
      coins += 3600; // +600 bonus
    } else if (sku == 'coin.7000') {
      coins += 8000; // +1000 bonus
    }

    await _persist();
    notifyListeners();
  }

  Future<void> spendCoins(int amount) async {
    if (coins >= amount) {
      coins -= amount;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> addCoins(int amount) async {
    coins += amount;
    await _persist();
    notifyListeners();
  }

  bool get firstFreeAvailable => !firstFreeUsed;

  Future<bool> tryConsumeForReading({required int coinCost}) async {
    if (tickets > 0) {
      tickets -= 1;
      lastUnlockMethod = 'ticket';
      await _persist();
      notifyListeners();
      return true;
    }
    if (!firstFreeUsed) {
      firstFreeUsed = true;
      lastUnlockMethod = 'first_free';
      await _persist();
      notifyListeners();
      return true; // first one is free
    }
    if (isPremium) { lastUnlockMethod = 'premium'; return true; }
    if (coins >= coinCost) {
      coins -= coinCost;
      lastUnlockMethod = 'coins';
      await _persist();
      notifyListeners();
      return true;
    }
    lastUnlockMethod = null;
    return false;
  }

  // Enforce coin-only consumption for specific readings (e.g., coffee)
  Future<bool> tryConsumeForReadingCoinsOnly({required int coinCost}) async {
    if (coins >= coinCost) {
      coins -= coinCost;
      lastUnlockMethod = 'coins';
      await _persist();
      notifyListeners();
      return true;
    }
    lastUnlockMethod = null;
    return false;
  }

  Future<void> grantDailyLoginBonus() async {
    coins += 10;
    energy = (energy + 10).clamp(0, 100);
    await _persist();
    notifyListeners();
  }

  Future<void> grantCampaignAfterThreeReads(int readsCompleted) async {
    if (readsCompleted >= 3) {
      tickets += 1; // 1 free reading
      await _persist();
      notifyListeners();
    }
  }

  Future<void> ensureDailyEnergyRefresh() async {
    final now = DateTime.now();
    final ymd = '${now.year}-${now.month}-${now.day}';
    if (_energyYmd == ymd) return;
    // Pseudo-random daily energy between 45..95 based on date
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final v = (seed % 51) + 45; // 45..95
    energy = v;
    _energyYmd = ymd;
    await _persist();
    notifyListeners();
  }
}
