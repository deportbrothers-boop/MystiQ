import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../common/widgets/gold_button.dart';
import '../../common/widgets/starry_background.dart';
import '../../theme/app_theme.dart';
import '../../core/ads/rewarded_helper.dart';
import '../../core/i18n/app_localizations.dart';
import 'product_catalog.dart';
import 'purchase_controller.dart';
import '../../core/format/price_formatter.dart';

class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ent = context.read<EntitlementsController>();
    return FutureBuilder<ProductCatalog>(
      future: ProductCatalog.load(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final catalog = snap.data!;
        final skus = {
          ...catalog.subscriptions.map((e) => e.sku),
          // Single-purchase items disabled
          ...catalog.coins.map((e) => e.sku),
        };
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ent),
            ChangeNotifierProvider(create: (_) => PurchaseController(onGrant: ent.grantFromSku)..init(skus.toSet())),
          ],
          child: _PaywallView(catalog: catalog),
        );
      },
    );
  }
}

class _PaywallView extends StatefulWidget {
  final ProductCatalog catalog;
  const _PaywallView({required this.catalog});

  @override
  State<_PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<_PaywallView> {
  int _remainingAds = 0;

  @override
  void initState() {
    super.initState();
    _refreshRemaining();
  }

  Future<void> _refreshRemaining() async {
    final r = await RewardedAds.remainingToday();
    if (mounted) setState(() => _remainingAds = r);
  }

  // Removed unused _snack helper

  @override
  Widget build(BuildContext context) {
    final ent = context.watch<EntitlementsController>();
    final store = context.watch<PurchaseController>();
    final loc = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        actions: [IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.close))],
      ),
      body: StarryBackground(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B0A0E), Color(0xFF121018)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: DefaultTabController(
              length: 2,
              initialIndex: 1,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text('MystiQ Premium', style: TextStyle(color: AppTheme.gold, fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: _HeroCard()),
                  const SizedBox(height: 8),
                  TabBar(
                    tabs: [
                      Tab(text: loc.t('paywall.tab.subs')),
                      Tab(text: loc.t('paywall.tab.coins')),
                    ],
                    indicatorColor: AppTheme.gold,
                    labelColor: AppTheme.gold,
                    unselectedLabelColor: AppTheme.muted,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.ondemand_video_outlined),
                          label: Text(loc.t('paywall.watch_ad') + (_remainingAds > 0 ? '  (${loc.t('paywall.left')}: $_remainingAds)' : '')),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final remaining = await RewardedAds.remainingToday();
                            if (remaining <= 0) {
                              messenger.showSnackBar(SnackBar(content: Text(loc.t('paywall.limit_reached'))));
                              return;
                            }
                            final ok = await RewardedAds.show(context: context);
                            if (ok && context.mounted) {
                              await ent.addCoins(10);
                              await RewardedAds.recordOne();
                              await _refreshRemaining();
                              messenger.showSnackBar(SnackBar(content: Text(loc.t('paywall.ad_coin_added'))));
                            }
                          },
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(children: [
                      _ListView(items: widget.catalog.subscriptions),
                      _ListView(items: widget.catalog.coins),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(ent.isPremium ? loc.t('paywall.premium_on') : loc.t('paywall.premium_off'), style: Theme.of(context).textTheme.bodySmall),
                      TextButton(
                        onPressed: store.available
                            ? () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await store.restore();
                                messenger.showSnackBar(SnackBar(content: Text(loc.t('paywall.restored'))));
                              }
                            : () {
                                final messenger = ScaffoldMessenger.of(context);
                                messenger.showSnackBar(SnackBar(content: Text(loc.t('paywall.store_unavailable'))));
                              },
                        child: Text(loc.t('paywall.restore')),
                      ),
                    ]),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Removed unused _Feature widget to clear lints.

class _ListView extends StatelessWidget {
  final List<CatalogItem> items;
  const _ListView({required this.items});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ProductTile(item: items[i]),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final CatalogItem item;
  const _ProductTile({required this.item});
  @override
  Widget build(BuildContext context) {
    final ent = context.watch<EntitlementsController>();
    final store = context.watch<PurchaseController>();
    final isSub = item.category == 'subscriptions';
    final isCoin = item.category == 'coins';
    final storeProduct = store.products[item.sku];
    final loc = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121018),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.1), blurRadius: 12, spreadRadius: 1)],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(isSub ? Icons.workspace_premium_outlined : Icons.auto_awesome, color: AppTheme.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_fixTr(_skuLabel(context, item, loc)), style: const TextStyle(fontWeight: FontWeight.w700)),
            if (_skuDesc(context, item, loc) != null) ...[
              const SizedBox(height: 4),
              Text(_fixTr(_skuDesc(context, item, loc)!), style: Theme.of(context).textTheme.bodySmall)
            ],
          ]),
        ),
        if (item.sku != 'lifetime.mystic_plus') TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.gold,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () async {
                  if (store.available && store.products.containsKey(item.sku)) {
                    await store.buy(item.sku);
                  } else {
                    await ent.grantFromSku(item.sku);
                    if (!context.mounted) return;
                    final name = _skuLabel(context, item, loc);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name ${loc.t('paywall.activated_mock')}')));
                  }
                },
                child: Text(
                  _formattedPrice(context, storeProduct?.price, item, loc),
                  style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700),
                ),
              )
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121018),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.45), width: 1.4),
        boxShadow: [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.25), blurRadius: 18, spreadRadius: 1)],
      ),
      child: Row(children: [const Icon(Icons.star, color: AppTheme.gold), const SizedBox(width: 12), Expanded(child: Text(_fixTr(loc.t('paywall.hero')), style: const TextStyle(fontWeight: FontWeight.w600)))]),
    );
  }
}

String _formattedPrice(BuildContext context, String? storePrice, CatalogItem item, AppLocalizations loc){
  final locale = Localizations.localeOf(context);
  // Force TRY display for Turkish users when we have a TRY price in catalog
  if (locale.languageCode.toLowerCase() == 'tr' && item.prices != null && item.prices!.containsKey('TRY')) {
    final amt = item.prices!['TRY']!;
    return PriceFormatter.format(amount: amt, currency: 'TRY', locale: const Locale('tr', 'TR'));
  }
  if (storePrice != null && storePrice.isNotEmpty) return storePrice;
  // Prefer multi-currency price if available
  if (item.prices != null && item.prices!.isNotEmpty) {
    final target = PriceFormatter.pickCurrencyForLocale(locale, supported: item.prices!.keys);
    final amt = item.prices![target];
    if (amt != null) {
      return PriceFormatter.format(amount: amt, currency: target, locale: locale);
    }
  }
  if (item.amount != null) {
    return PriceFormatter.format(amount: item.amount!, currency: item.currency, locale: locale);
  }
  return item.price ?? loc.t('paywall.buy');
}

String _skuLabel(BuildContext context, CatalogItem item, AppLocalizations loc) {
  final key = 'sku.${item.sku}.label';
  final v = loc.t(key);
  return v != key ? v : item.label;
}

String? _skuDesc(BuildContext context, CatalogItem item, AppLocalizations loc) {
  final key = 'sku.${item.sku}.desc';
  final v = loc.t(key);
  if (v != key) return v;
  return item.desc;
}

String _fixTr(String s) {
  if (s.isEmpty) return s;
  var out = s;
  // Multi-pass Latin1->UTF8 repair for double-encoded fragments (e.g., Ã„Â±)
  for (var i = 0; i < 3; i++) {
    try {
      final repaired = utf8.decode(latin1.encode(out), allowMalformed: true);
      if (repaired == out) break;
      out = repaired;
    } catch (_) { break; }
  }
  const map = {
    'Ã§':'ç','Ã¶':'ö','Ã¼':'ü','Ä±':'ı','ÄŸ':'ğ','ÅŸ':'ş',
    'Ã‡':'Ç','Ã–':'Ö','Ãœ':'Ü','Ä°':'İ','Äž':'Ğ','Åž':'Ş',
    'â€™':'’','â€˜':'‘','â€œ':'“','â€':'”','â€“':'–','â€”':'—','â€¢':'•',
    'Â·':'·','Â':'',
  };
  map.forEach((k,v){ out = out.replaceAll(k, v); });
  out = out.replaceAll('\uFFFD', '');
  return out;
}

String _fixText(String s) {
  if (s.isEmpty) return s;
  var out = s;
  try { out = utf8.decode(latin1.encode(out)); } catch (_) {}
  const map = {
    'Ã§':'ç','Ã¶':'ö','Ã¼':'ü','Ä±':'ı','ÄŸ':'ğ','ÅŸ':'ş',
    'Ã‡':'Ç','Ã–':'Ö','Ãœ':'Ü','Ä°':'İ','Äž':'Ğ','Åž':'Ş',
    'â€™':'’','â€˜':'‘','â€œ':'“','â€':'”','â€“':'–','â€”':'—','â€¢':'•',
    'Â·':'·','Â':'',
  };
  map.forEach((k,v){ out = out.replaceAll(k, v); });
  out = out.replaceAll('\uFFFD', '');
  return out;
}
