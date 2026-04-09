import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../common/widgets/starry_background.dart';
import '../../core/ads/rewarded_helper.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/purchase/purchase_service.dart';
import '../../theme/app_theme.dart';

/// Bu projede gerçek para ile ödeme yoktur.
/// Coin yalnızca reklam izleyerek kazanılır.
class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ent = context.read<EntitlementsController>();
    return ChangeNotifierProvider.value(
      value: ent,
      child: const _EarnCoinsView(),
    );
  }
}

class _EarnCoinsView extends StatefulWidget {
  const _EarnCoinsView();
  @override
  State<_EarnCoinsView> createState() => _EarnCoinsViewState();
}

class _EarnCoinsViewState extends State<_EarnCoinsView> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pkgs = await PurchaseService.getPackages();
    if (mounted) setState(() { _packages = pkgs; _loading = false; });
  }

  Future<void> _buy(Package pkg) async {
    setState(() => _purchasing = true);
    final ent = context.read<EntitlementsController>();
    final ok = await PurchaseService.purchase(pkg, ent);
    if (mounted) {
      setState(() => _purchasing = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  Future<void> _restore() async {
    setState(() => _purchasing = true);
    final ent = context.read<EntitlementsController>();
    final ok = await PurchaseService.restore(ent);
    if (mounted) {
      setState(() => _purchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Abonelik geri yüklendi' : 'Aktif abonelik bulunamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 16),
                  const Text('Pro\'ya Geç', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Reklamlara son, sınırsız yorum', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 24),
                  if (_packages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Paketler yüklenemedi. Lütfen tekrar dene.'),
                    )
                  else
                    ..._packages.map((pkg) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _purchasing ? null : () => _buy(pkg),
                          child: Text(
                            '${pkg.storeProduct.title} — ${pkg.storeProduct.priceString}',
                          ),
                        ),
                      ),
                    )),
                  const Spacer(),
                  TextButton(
                    onPressed: _purchasing ? null : _restore,
                    child: const Text('Satın alımı geri yükle'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }
}
