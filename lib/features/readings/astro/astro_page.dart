import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ai/local_generator.dart';
import '../../profile/profile_controller.dart';
import '../../../core/entitlements/entitlements_controller.dart';
import '../../history/history_controller.dart';
import '../../history/history_entry.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/readings/pending_readings_service.dart';
import '../../../core/access/access_gate.dart';
import '../../../core/access/sku_costs.dart';

class AstroPage extends StatefulWidget {
  const AstroPage({super.key});
  @override
  State<AstroPage> createState() => _AstroPageState();
}

class _AstroPageState extends State<AstroPage> {
  String? text;
  bool _streaming = false;
  StreamSubscription<String>? _sub;
  Timer? _fallbackTimer;
  bool _didComplete = false;
  String _style = 'practical'; // 'practical' | 'spiritual'

  @override
  void dispose() {
    _sub?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>().profile;
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('astro.title'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${loc.t('astro.zodiac')}${profile.zodiac.isEmpty ? '-' : profile.zodiac}'),
            const SizedBox(height: 12),
            // Üslup (Pratik / Spiritüel)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      loc.t('astro.style.title') != 'astro.style.title' ? loc.t('astro.style.title') : 'Üslup',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(loc.t('astro.style.practical') != 'astro.style.practical' ? loc.t('astro.style.practical') : 'Pratik'),
                        selected: _style == 'practical',
                        onSelected: (_) => setState(() => _style = 'practical'),
                      ),
                      ChoiceChip(
                        label: Text(loc.t('astro.style.spiritual') != 'astro.style.spiritual' ? loc.t('astro.style.spiritual') : 'Spiritüel'),
                        selected: _style == 'spiritual',
                        onSelected: (_) => setState(() => _style = 'spiritual'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (text != null)
              Expanded(child: SingleChildScrollView(child: Text(text!)))
            else
              Expanded(child: Center(child: Text(loc.t('astro.empty_hint')))),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final ok = await AccessGate.ensureCoinsOnlyOrPaywall(
                  context,
                  coinCost: SkuCosts.astro,
                );
                if (!ok || !mounted) return;
                try {
                  final profile = context.read<ProfileController>().profile;
                  final locale = Localizations.localeOf(context).languageCode;
                  final generated = LocalAIGenerator.generate(
                    type: 'astro',
                    profile: profile,
                    extras: {'style': _style},
                    locale: locale,
                  );
                  final hc = context.read<HistoryController>();
                  final entry = HistoryEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: 'astro',
                    title: AppLocalizations.of(context).t('astro.title'),
                    text: generated,
                    createdAt: DateTime.now(),
                  );
                  await hc.add(entry);
                  if (!mounted) return;
                  context.push('/reading/result/astro', extra: entry);
                } catch (_) {
                  if (!mounted) return;
                  // Fallback: Result sayfasında yerelde üret
                  context.push('/reading/result/astro', extra: {
                    'style': _style,
                    'noStream': true,
                    'forceLocal': true,
                  });
                }
              },
              child: Text(loc.t('astro.create_button')),
            ),
          ],
        ),
      ),
    );
  }
}

