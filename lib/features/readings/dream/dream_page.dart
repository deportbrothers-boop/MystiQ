import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/access/access_gate.dart';
import '../../../core/access/ai_generation_guard.dart';
import '../../../core/access/sku_costs.dart';
import '../../../core/ads/rewarded_helper.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/readings/pending_readings_service_fixed.dart';
import '../../../core/readings/reading_timing.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';

class DreamPage extends StatefulWidget {
  const DreamPage({super.key});

  @override
  State<DreamPage> createState() => _DreamPageState();
}

class _DreamPageState extends State<DreamPage> {
  final ctrl = TextEditingController();
  static const String _prefix = 'RÜYAMDA ';
  bool _handlingPrefix = false;
  final String _style = 'practical';

  @override
  void initState() {
    super.initState();
    ctrl.text = _prefix;
    ctrl.selection = const TextSelection.collapsed(offset: _prefix.length);
    ctrl.addListener(_enforcePrefix);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _redirectToPendingIfAny());
  }

  @override
  void dispose() {
    ctrl.removeListener(_enforcePrefix);
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _redirectToPendingIfAny() async {
    try {
      final item = await PendingReadingsService.firstPendingOfType('dream');
      if (!mounted || item == null) return;
      final readyAt = DateTime.tryParse((item['readyAt'] as String?) ?? '');
      if (readyAt == null) return;
      final pendingId = item['id']?.toString();
      final extras = (item['extras'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      context.push('/reading/result/dream', extra: {
        ...extras,
        'etaSeconds':
            readyAt.difference(DateTime.now()).inSeconds.clamp(0, 86400),
        'readyAt': readyAt.toIso8601String(),
        'generateAtReady': true,
        if (pendingId != null && pendingId.isNotEmpty) 'pendingId': pendingId,
      });
    } catch (_) {}
  }

  void _enforcePrefix() {
    if (_handlingPrefix) return;
    _handlingPrefix = true;
    final text = ctrl.text;
    final sel = ctrl.selection;

    var newText = text;
    var newSelection = sel;

    if (!text.startsWith(_prefix)) {
      final withoutPrefix = text.replaceAll(_prefix, '');
      newText = '$_prefix$withoutPrefix';
      var offset = sel.baseOffset;
      if (offset < _prefix.length) offset = _prefix.length;
      if (offset > newText.length) offset = newText.length;
      newSelection = TextSelection.collapsed(offset: offset);
    } else if (sel.baseOffset < _prefix.length) {
      newSelection = const TextSelection.collapsed(offset: _prefix.length);
    }

    ctrl.value = TextEditingValue(text: newText, selection: newSelection);
    _handlingPrefix = false;
  }

  Future<void> _startDream({required bool viaAd}) async {
    String permit = '';
    if (viaAd) {
      final okAd = await RewardedAds.showMultiple(
          context: context, count: 2, key: 'dream');
      if (!okAd || !context.mounted) {
        final msg = AppLocalizations.of(context).t('tarot.fast.ad_failed') !=
                'tarot.fast.ad_failed'
            ? AppLocalizations.of(context).t('tarot.fast.ad_failed')
            : 'Reklam gösterilemedi. Tekrar deneyin.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
      permit = await AiGenerationGuard.issuePermit();
    } else {
      final ok = await AccessGate.ensureCoinsOnlyOrPaywall(context,
          coinCost: SkuCosts.dream);
      if (!ok || !context.mounted) return;
      permit = await AiGenerationGuard.issuePermit();
    }

    final eta = ReadingTiming.initialWaitFor('dream');
    final readyAt = DateTime.now().add(eta);
    String? pendingId;
    try {
      final locale = Localizations.localeOf(context).languageCode;
      final extras = <String, dynamic>{
        'text': ctrl.text,
        'style': _style,
        'permit': permit,
        if (viaAd) 'adBoost': true,
      };
      pendingId = await PendingReadingsService.schedule(
        type: 'dream',
        readyAt: readyAt,
        extras: extras,
        locale: locale,
      );
      try {
        final hc = context.read<HistoryController>();
        if (pendingId != null) {
          await hc.upsert(HistoryEntry(
            id: pendingId,
            type: 'dream',
            title: AppLocalizations.of(context).t('dream.title'),
            text: AppLocalizations.of(context).t('reading.preparing'),
            createdAt: DateTime.now(),
          ));
        }
      } catch (_) {}
    } catch (_) {}

    if (!context.mounted) return;
    context.push('/reading/result/dream', extra: {
      'text': ctrl.text,
      'style': _style,
      'permit': permit,
      if (viaAd) 'adBoost': true,
      'etaSeconds': eta.inSeconds,
      'readyAt': readyAt.toIso8601String(),
      'generateAtReady': true,
      if (pendingId != null) 'pendingId': pendingId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(AppLocalizations.of(context).t('dream.title'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 8),
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
                onPressed: () async => _startDream(viaAd: true),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('2 Reklam izle, Yorum Al'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async => _startDream(viaAd: false),
                child: Builder(
                  builder: (ctx) {
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
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
