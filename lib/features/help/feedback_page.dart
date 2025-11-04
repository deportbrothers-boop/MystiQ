import '../../core/i18n/app_localizations.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final emailCtrl = TextEditingController();
  final msgCtrl = TextEditingController();
  List<Map<String, String>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList('feedback_list') ?? [];
    setState(() {
      items = list.map((e) => Map<String, String>.from(json.decode(e))).toList();
    });
  }

  Future<void> _save() async {
    final email = emailCtrl.text.trim();
    final msg = msgCtrl.text.trim();
    if (msg.isEmpty) return;
    final it = {'email': email, 'message': msg, 'ts': DateTime.now().toIso8601String()};
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList('feedback_list') ?? [];
    list.insert(0, json.encode(it));
    await sp.setStringList('feedback_list', list);
    emailCtrl.clear();
    msgCtrl.clear();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).t('help.feedback.saved'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('help.feedback.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: emailCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context).t('help.feedback.email_optional'))),
          const SizedBox(height: 8),
          TextField(
            controller: msgCtrl,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).t('help.feedback.message_label'), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton(onPressed: _save, child: Text(AppLocalizations.of(context).t('action.send'))),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: items.isEmpty ? null : () => Share.share(items.map((e) => '${e['ts']}: ${e['message']}').join('\n')),
              child: Text(AppLocalizations.of(context).t('action.export')),
            ),
          ]),
          const Divider(height: 24),
          ...items.map((e) => ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: Text(e['message'] ?? ''),
                subtitle: Text(e['ts'] ?? ''),
              )),
        ],
      ),
    );
  }
}





