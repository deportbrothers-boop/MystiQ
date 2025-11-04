import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/entitlements/entitlements_controller.dart';

class MotivationPage extends StatelessWidget {
  const MotivationPage({super.key});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final now = DateTime.now();
    final tipKey = 'daily.tip.${(((now.weekday - 1) % 7) + 1)}';
    final tip = loc.t(tipKey);
    String date;
    try {
      date = DateFormat('EEEE, d MMM', Localizations.localeOf(context).toLanguageTag()).format(now);
    } catch (_) {
      date = DateFormat('EEEE, d MMM').format(now);
    }
    final longText = _buildLongMotivation(context, tip);
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('motivation.title'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(longText, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  // Compose a longer, day-variant motivation text using energy + weekday.
  String _buildLongMotivation(BuildContext context, String dailyTip) {
    final ent = context.read<EntitlementsController>();
    final energy = ent.energy; // 0..100
    final seed = DateTime.now().difference(DateTime(2022, 1, 1)).inDays;

    String pick(List<String> items, int s) => items.isEmpty ? '' : items[s % items.length];
    List<String> loadList(AppLocalizations loc, String base) {
      final out = <String>[];
      for (var i = 0; i < 12; i++) {
        final k = '$base.$i';
        final v = loc.t(k);
        if (v == k) break; // stop when key missing
        if (v.trim().isNotEmpty) out.add(v);
      }
      return out;
    }

    final loc = AppLocalizations.of(context);
    var intros = loadList(loc, 'motivation.intro');
    var actions = loadList(loc, 'motivation.action');
    var closers = loadList(loc, 'motivation.closer');

    // Fallbacks if i18n missing
    intros = intros.isNotEmpty ? intros : [
      'Bugun kendine nazikce yonel; kucuk ama net adimlar guzel degisimler baslatir.',
      'Derin bir nefes al; niyetini tek cumleye indir ve gunu o netlikle tasimaya calis.',
      'Zihnini hafiflet, kalbini ac; bugun yalnizca tek bir hedefe odaklan.'
    ];
    actions = actions.isNotEmpty ? actions : [
      '3 derin nefes al ve "birakiyorum" diyerek ver.',
      'Niyetini tek cumleyle yaz; telefonuna kaydet.',
      '10 dakikalik tek-odak zamani ayir; bildirimleri kapat.',
      'Bir bardak su ic; bedeni canlandir.',
      '5 dakikalik yuruyuste yalnizca adimlarini say.',
      'Bugun birine kisacik tesekkur et.'
    ];
    closers = closers.isNotEmpty ? closers : [
      'Gun sonunda iki cumleyle kendini kutla.',
      'Bugun bir adim attin; yarina hafiflik tasin.',
      'Kisacik bir gulumsemeyle niyetini muhurle.'
    ];

    final intro = pick(intros, seed + (energy ~/ 10));
    final a1 = pick(actions, seed + 1);
    final a2 = pick(actions, seed + 3);
    final a3 = pick(actions, seed + 5);
    final closer = pick(closers, seed + 7);

    final buf = StringBuffer()
      ..writeln(dailyTip)
      ..writeln()
      ..writeln(intro)
      ..writeln()
      ..writeln('- $a1')
      ..writeln('- $a2')
      ..writeln('- $a3')
      ..writeln()
      ..writeln(closer);

    final text = buf.toString().trim();
    if (text.length < 360) {
      final extra = pick(actions, seed + 9);
      return '$text\n- $extra';
    }
    return text;
  }
}

