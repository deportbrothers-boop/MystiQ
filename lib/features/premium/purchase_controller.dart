import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class PurchaseController with ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool available = false;
  bool loading = true;
  Map<String, ProductDetails> products = {};
  final void Function(String sku)? onGrant;
  String _verifyUrl = '';

  PurchaseController({this.onGrant});

  Future<void> init(Set<String> skus) async {
    loading = true;
    notifyListeners();
    // Load optional verification proxy URL
    try {
      final txt = await rootBundle.loadString('assets/config/auth.json');
      final j = json.decode(txt) as Map<String, dynamic>;
      _verifyUrl = (j['purchasesProxyUrl'] ?? '') as String;
    } catch (_) {}
    available = await _iap.isAvailable();
    if (!available) {
      loading = false;
      notifyListeners();
      return;
    }
    final res = await _iap.queryProductDetails(skus);
    products = {for (final p in res.productDetails) p.id: p};
    _subscription = _iap.purchaseStream.listen(_onPurchases, onDone: () {
      _subscription.cancel();
    });
    loading = false;
    notifyListeners();
  }

  Future<void> buy(String sku) async {
    final p = products[sku];
    if (p == null) return;
    final param = PurchaseParam(productDetails: p);
    if (sku.startsWith('coin.')) {
      await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
    } else {
      await _iap.buyNonConsumable(purchaseParam: param);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      if (pd.status == PurchaseStatus.purchased ||
          pd.status == PurchaseStatus.restored) {
        var ok = true;
        if (_verifyUrl.isNotEmpty) {
          try {
            final payload = {
              'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
              'productId': pd.productID,
              'verificationData': {
                'serverVerificationData': pd.verificationData.serverVerificationData,
                'localVerificationData': pd.verificationData.localVerificationData,
                'source': pd.verificationData.source,
              }
            };
            final r = await http.post(Uri.parse(_verifyUrl), headers: {'content-type': 'application/json'}, body: json.encode(payload));
            if (r.statusCode >= 200 && r.statusCode < 300) {
              final jr = json.decode(r.body) as Map<String, dynamic>;
              ok = (jr['ok'] == true) && (jr['verified'] != false);
            } else {
              ok = false;
            }
          } catch (_) {
            ok = false;
          }
        }
        if (ok) {
          onGrant?.call(pd.productID);
        }
        if (pd.pendingCompletePurchase) {
          await _iap.completePurchase(pd);
        }
      }
    }
    notifyListeners();
  }

  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  @override
  void dispose() {
    try {
      _subscription.cancel();
    } catch (_) {}
    super.dispose();
  }
}
