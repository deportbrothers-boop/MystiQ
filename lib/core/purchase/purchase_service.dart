import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../entitlements/entitlements_controller.dart';

class PurchaseService {
  static const _androidKey = 'goog_DfknFqQyVKIOyajiyCXCaNQmFTK';
  static const _iosKey = 'appl_kRqxgKCUndAVALBDNUUeuvrKyCx';

  static Future<void> init() async {
    final key = Platform.isIOS ? _iosKey : _androidKey;
    await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration(key);
    await Purchases.configure(config);
  }

  static Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('[Purchase] getPackages error: $e');
      return [];
    }
  }

  static Future<bool> purchase(
    Package package,
    EntitlementsController ent,
  ) async {
    try {
      final info = await Purchases.purchasePackage(package);
      final active = info.entitlements.active;
      if (active.containsKey('pro')) {
        final expiry = active['pro']?.expirationDate;
        final sku = package.storeProduct.identifier;
        if (expiry != null) {
          ent.premiumSku = sku;
          ent.premiumUntil = DateTime.parse(expiry);
        } else {
          await ent.grantFromSku('lifetime.mystic_plus');
        }
        await ent.grantFromSku(sku);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Purchase] error: $e');
      return false;
    }
  }

  static Future<bool> restore(EntitlementsController ent) async {
    try {
      final info = await Purchases.restorePurchases();
      final active = info.entitlements.active;
      if (active.containsKey('pro')) {
        final expiry = active['pro']?.expirationDate;
        final sku = active['pro']?.productIdentifier ?? 'sub.premium.monthly';
        if (expiry != null) {
          ent.premiumSku = sku;
          ent.premiumUntil = DateTime.parse(expiry);
        } else {
          await ent.grantFromSku('lifetime.mystic_plus');
        }
        await ent.grantFromSku(sku);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Purchase] restore error: $e');
      return false;
    }
  }
}
