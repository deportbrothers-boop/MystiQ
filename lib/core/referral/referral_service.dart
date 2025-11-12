import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import '../access/sku_costs.dart';
import '../entitlements/entitlements_controller.dart';

class ReferralService {
  static const _kMyCode = 'ref.my_code';
  static const _kUsed = 'ref.redeemed_codes';
  static const _kPromoUsed = 'promo.used_codes';
  static const _kPromoOnce = 'promo.once_used';

  static Future<String> myCode() async {
    final sp = await SharedPreferences.getInstance();
    var code = sp.getString(_kMyCode);
    if (code == null || code.isEmpty) {
      code = _gen(6);
      await sp.setString(_kMyCode, code);
    }
    return code;
  }

  static String _gen(int n) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random(DateTime.now().microsecondsSinceEpoch);
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Future<bool> redeemReferral({required String code, required EntitlementsController ent}) async {
    code = code.trim().toUpperCase();
    if (code.isEmpty) return false;
    final sp = await SharedPreferences.getInstance();
    final mine = sp.getString(_kMyCode) ?? '';
    if (code == mine) return false; // cannot use own code
    final used = sp.getStringList(_kUsed) ?? <String>[];
    if (used.contains(code)) return false;
    used.add(code);
    await sp.setStringList(_kUsed, used);
    await ent.addCoins(SkuCosts.coffeeFast); // 1 reading right ~ 100 coins
    return true;
  }

  static Future<void> shareMyCode(BuildContext context) async {
    final code = await myCode();
    final msg = 'MystiQ referans kodum: $code\nKullan, 1 fal hakki kazan!';
    await Share.share(msg, subject: 'MystiQ Referans Kodu');
  }

  // Promo: single-use per user, always grants 1 reading (100 coins)
  static Future<bool> redeemPromo({required String code, required EntitlementsController ent}) async {
    code = code.trim().toUpperCase();
    if (code.isEmpty) return false;
    final sp = await SharedPreferences.getInstance();
    if (sp.getBool(_kPromoOnce) == true) return false;
    // basic format check
    final valid = RegExp(r'^[A-Z0-9]{4,}$').hasMatch(code);
    if (!valid) return false;
    final used = sp.getStringList(_kPromoUsed) ?? <String>[];
    if (used.contains(code)) return false;
    used.add(code);
    await sp.setStringList(_kPromoUsed, used);
    await sp.setBool(_kPromoOnce, true);
    await ent.addCoins(SkuCosts.coffeeFast);
    return true;
  }
}

