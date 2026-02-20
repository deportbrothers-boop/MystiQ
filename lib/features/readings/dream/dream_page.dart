import 'package:flutter/material.dart';
import '../../../core/i18n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/ai_generation_guard.dart';
import '../../../core/access/sku_costs.dart';
import 'package:provider/provider.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../profile/profile_controller.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import '../../../core/entitlements/entitlements_controller.dart';

class DreamPage extends StatefulWidget {
  const DreamPage({super.key});
  @override
  State<DreamPage> createState() => _DreamPageState();
}

class _DreamPageState extends State<DreamPage> {
  final ctrl = TextEditingController();
  static const String _prefix = 'RÜYAMDA ';
  bool _handlingPrefix = false;
  String _style = 'practical'; // 'poetic' | 'practical' (but hidden UI)

  @override
  void initState() {
    super.initState();
    ctrl.text = _prefix;
    ctrl.selection = const TextSelection.collapsed(offset: _prefix.length);
    ctrl.addListener(_enforcePrefix);
  }

  @override
  void dispose() {
    ctrl.removeListener(_enforcePrefix);
    ctrl.dispose();
    super.dispose();
  }

  void _enforcePrefix() {
    if (_handlingPrefix) return;
    _handlingPrefix = true;
    final text = ctrl.text;
    final sel = ctrl.selection;

    String newText = text;
    TextSelection newSelection = sel;

    // Metin RÜYAMDA ile başlamıyorsa, prefix'i tekrar ekle.
    if (!text.startsWith(_prefix)) {
      final withoutPrefix = text.replaceAll(_prefix, '');
      newText = '$_prefix$withoutPrefix';
      var offset = sel.baseOffset;
      if (offset < _prefix.length) offset = _prefix.length;
      if (offset > newText.length) offset = newText.length;
      newSelection = TextSelection.collapsed(offset: offset);
    } else if (sel.baseOffset < _prefix.length) {
      // İmlecin prefix'in soluna gitmesine izin verme.
      newSelection = const TextSelection.collapsed(offset: _prefix.length);
    }

    ctrl.value = TextEditingValue(text: newText, selection: newSelection);
    _handlingPrefix = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('dream.title'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).t('dream.input_label'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async => _startDream(context, viaAd: true),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('2 Reklam izle, Yorum Al'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async => _startDream(context, viaAd: false),
                child: Builder(builder: (ctx) {
                  final cost = SkuCosts.dream;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppLocalizations.of(context).t('dream.cta')),
                      const SizedBox(width: 8),
                      const Icon(Icons.monetization_on_outlined, size: 16),
                      const SizedBox(width: 2),
                      Text('$cost'),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _DreamPageState {
  Future<void> _startDream(BuildContext context, {required bool viaAd}) async {
    String permit = '';
    if (viaAd) {
      final okAd = await RewardedAds.showMultiple(context: context, count: 2, key: 'dream');
      if (!okAd || !context.mounted) {
        final msg = AppLocalizations.of(context).t('tarot.fast.ad_failed') != 'tarot.fast.ad_failed'
            ? AppLocalizations.of(context).t('tarot.fast.ad_failed')
            : 'Reklam gosterilemedi. Tekrar deneyin.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
      permit = await AiGenerationGuard.issuePermit();
    } else {
      final ok = await AccessGate.ensureCoinsOnlyOrPaywall(context, coinCost: SkuCosts.dream);
      if (!ok || !context.mounted) return;
      permit = await AiGenerationGuard.issuePermit();
    }

    try {
      final profile = context.read<ProfileController>().profile;
      final locale = Localizations.localeOf(context).languageCode;
      final generated = await AiService.generate(
        type: 'dream',
        profile: profile,
        extras: {'text': ctrl.text, 'style': _style, 'permit': permit},
        locale: locale,
      );
      // If AI failed after consuming coins, refund and stop here
      if (generated.startsWith('Uretim su anda yapilamiyor')) {
        final entNow = context.read<EntitlementsController>();
        if (entNow.lastUnlockMethod == 'coins') {
          try { await entNow.addCoins(SkuCosts.dream); } catch (_) {}
        }
        if (context.mounted) {
          final msg = AppLocalizations.of(context).t('error.ai_unavailable_refund') != 'error.ai_unavailable_refund'
              ? AppLocalizations.of(context).t('error.ai_unavailable_refund')
              : 'Ag sorunu: coin iade edildi. Lutfen bir sure sonra tekrar deneyin.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }
      final hc = context.read<HistoryController>();
      final entry = HistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'dream',
        title: AppLocalizations.of(context).t('dream.title'),
        text: generated,
        createdAt: DateTime.now(),
      );
      await hc.add(entry);
      if (!context.mounted) return;
      context.push('/reading/result/dream', extra: entry);
    } catch (_) {
      // Refund coins if they were consumed, then inform user and do not navigate
      try {
        final entNow = context.read<EntitlementsController>();
        if (entNow.lastUnlockMethod == 'coins') {
          await entNow.addCoins(SkuCosts.dream);
        }
      } catch (_) {}
      if (!context.mounted) return;
      final msg = AppLocalizations.of(context).t('error.ai_unavailable_refund') != 'error.ai_unavailable_refund'
          ? AppLocalizations.of(context).t('error.ai_unavailable_refund')
          : 'Ag sorunu: coin iade edildi. Lutfen bir sure sonra tekrar deneyin.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
  }
}








