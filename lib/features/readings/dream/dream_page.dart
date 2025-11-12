import 'package:flutter/material.dart';
import '../../../core/i18n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/sku_costs.dart';
import 'package:provider/provider.dart';
import '../../../core/ai/ai_service.dart';
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
  String _style = 'practical'; // 'poetic' | 'practical' (but hidden UI)

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
            ElevatedButton(
              onPressed: () async {
                // Unified flow: schedule + countdown for all readings
                await _startDream(context);
                return;
                final ok = await AccessGate.ensureAccessOrPaywall(
                  context,
                  sku: 'reading.dream',
                  coinCost: SkuCosts.dream,
                );
                if (ok && context.mounted) {
                  // Yorumu hemen Ã¼ret ve geÃ§miÅŸe kaydet; sonra Result'a gÃ¶nder
                  final profile = context.read<ProfileController>().profile;
                  final locale = Localizations.localeOf(context).languageCode;
                  final generated = await AiService.generate(
                    type: 'dream',
                    profile: profile,
                    extras: {'text': ctrl.text},
                    locale: locale,
                  );
                  try {
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
                    if (!context.mounted) return;
                    context.push('/reading/result/dream', extra: {
                      'text': generated,
                    });
                  }
                }
              },
              child: Builder(builder: (ctx) {
                final ent = ctx.watch<EntitlementsController>();
                final cost = (ent.isPremium || !ent.firstFreeUsed) ? 0 : SkuCosts.dream;
                final loc = AppLocalizations.of(context);
                final reason = ent.isPremium
                    ? (loc.t('premium.free_reason') != 'premium.free_reason' ? loc.t('premium.free_reason') : 'Premium: 0 coin')
                    : (loc.t('first_free.reason') != 'first_free.reason' ? loc.t('first_free.reason') : 'Ä°lk fal Ã¼cretsiz: 0 coin');
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(AppLocalizations.of(context).t('dream.cta')),
                    const SizedBox(width: 8),
                    const Icon(Icons.monetization_on_outlined, size: 16),
                    const SizedBox(width: 2),
                    Text('$cost'),
                    if (cost == 0) ...[
                      const SizedBox(width: 6),
                      Tooltip(message: reason, child: const Icon(Icons.info_outline, size: 16)),
                    ],
                  ],
                );
              })
            ),
          ],
        ),
      ),
    );
  }
}

extension on _DreamPageState {
  Future<void> _startDream(BuildContext context) async {
    final ok = await AccessGate.ensureAccessOrPaywall(
      context,
      sku: 'reading.dream',
      coinCost: SkuCosts.dream,
    );
    if (!ok || !context.mounted) return;

    try {
      final profile = context.read<ProfileController>().profile;
      final locale = Localizations.localeOf(context).languageCode;
      final generated = await AiService.generate(
        type: 'dream',
        profile: profile,
        extras: {'text': ctrl.text, 'style': _style},
        locale: locale,
      );
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
      if (!context.mounted) return;
      context.push('/reading/result/dream', extra: {
        'text': ctrl.text,
        'style': _style,
      });
    }
  }
}








