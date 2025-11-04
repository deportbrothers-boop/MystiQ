import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CatalogItem {
  final String sku;
  final String label;
  final String? price;
  final String? desc;
  final String category; // subscriptions | onetime | coins
  final double? amount; // numeric price amount
  final String? currency; // ISO 4217 (e.g., TRY, USD)
  final Map<String, double>? prices; // Multi-currency map

  CatalogItem({
    required this.sku,
    required this.label,
    required this.category,
    this.price,
    this.desc,
    this.amount,
    this.currency,
    this.prices,
  });

  static String _fix(String? s) {
    if (s == null || s.isEmpty) return s ?? '';
    if (s.contains('Ã') || s.contains('Â') || s.contains('â')) {
      try {
        final bytes = latin1.encode(s);
        return utf8.decode(bytes);
      } catch (_) {
        return s;
      }
    }
    return s;
  }

  factory CatalogItem.fromJson(Map<String, dynamic> j, String category) =>
      CatalogItem(
        sku: j['sku'] as String,
        label: _fix(j['label'] as String?),
        price: _fix(j['price'] as String?),
        desc: _fix(j['desc'] as String?),
        category: category,
        amount: (j['amount'] is num) ? (j['amount'] as num).toDouble() : null,
        currency: j['currency'] as String?,
        prices: (j['prices'] is Map<String, dynamic>)
            ? (j['prices'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()))
            : null,
      );
}

class ProductCatalog {
  final List<CatalogItem> subscriptions;
  final List<CatalogItem> onetime;
  final List<CatalogItem> coins;

  ProductCatalog({
    required this.subscriptions,
    required this.onetime,
    required this.coins,
  });

  static Future<ProductCatalog> load() async {
    final txt = await rootBundle.loadString('assets/config/products.json');
    final j = json.decode(txt) as Map<String, dynamic>;
    List<CatalogItem> parse(String key) =>
        (j[key] as List).map((e) => CatalogItem.fromJson(e, key)).toList();
    return ProductCatalog(
      subscriptions: parse('subscriptions'),
      onetime: parse('onetime'),
      coins: parse('coins'),
    );
  }
}
