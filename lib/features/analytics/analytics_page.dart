import 'package:flutter/material.dart';
import '../../core/analytics/analytics.dart';
import '../../core/i18n/app_localizations.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Map<String, int> data = const {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Analytics.summary();
    setState(() => data = s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('analytics.local_title'))),
      body: ListView(
        children: [
          ...data.entries.map((e) => ListTile(title: Text(e.key), trailing: Text('${e.value}'))),
          const SizedBox(height: 8),
          Center(
            child: OutlinedButton(
              onPressed: () async { await Analytics.clear(); await _load(); },
              child: Text(AppLocalizations.of(context).t('action.clear')),
            ),
          )
        ],
      ),
    );
  }
}


