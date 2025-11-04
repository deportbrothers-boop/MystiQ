import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('help.faq.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Q(q: AppLocalizations.of(context).t('help.faq.q1'), a: AppLocalizations.of(context).t('help.faq.a1')),
          _Q(q: AppLocalizations.of(context).t('help.faq.q2'), a: AppLocalizations.of(context).t('help.faq.a2')),
          _Q(q: AppLocalizations.of(context).t('help.faq.q3'), a: AppLocalizations.of(context).t('help.faq.a3')),
          _Q(q: AppLocalizations.of(context).t('help.faq.q4'), a: AppLocalizations.of(context).t('help.faq.a4')),
        ],
      ),
    );
  }
}

class _Q extends StatelessWidget {
  final String q, a;
  const _Q({required this.q, required this.a});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(q, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(a),
      ]),
    );
  }
}


