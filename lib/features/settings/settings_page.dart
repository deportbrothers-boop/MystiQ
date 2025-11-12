import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/i18n/locale_controller.dart';
import '../legal/legal_pages.dart';
import '../../core/i18n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final ctrl = context.watch<LocaleController>();
    final current = ctrl.locale?.languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(loc.t('settings.title'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(loc.t('settings.language')),
            subtitle: Text(_labelFor(current, loc)),
            onTap: () => _openLanguageSheet(context, current),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(loc.t('legal.privacy_short')),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPage()),
              );
            },
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text(loc.t('settings.fcm.reset_title')),
            subtitle: Text(loc.t('settings.fcm.reset_sub')),
            onTap: () async {
              try {
                await FirebaseMessaging.instance.deleteToken();
                final newToken = await FirebaseMessaging.instance.getToken();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(newToken != null ? AppLocalizations.of(context).t('settings.fcm.reset_ok') : AppLocalizations.of(context).t('settings.fcm.reset_fail'))),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context).t('settings.fcm.reset_error_prefix') + ' ' + e.toString())),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _openLanguageSheet(BuildContext context, String? current) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangTile(code: null, label: loc.t('lang.system'), selected: current == null),
            _LangTile(code: 'tr', label: loc.t('lang.tr'), selected: current == 'tr'),
            _LangTile(code: 'en', label: loc.t('lang.en'), selected: current == 'en'),
            _LangTile(code: 'es', label: loc.t('lang.es'), selected: current == 'es'),
            _LangTile(code: 'ar', label: loc.t('lang.ar'), selected: current == 'ar'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _labelFor(String? code, AppLocalizations loc) {
    switch (code) {
      case 'tr':
        return loc.t('lang.tr');
      case 'en':
        return loc.t('lang.en');
      case 'es':
        return loc.t('lang.es');
      case 'ar':
        return loc.t('lang.ar');
      default:
        return loc.t('lang.system');
    }
  }
}

class _LangTile extends StatelessWidget {
  final String? code;
  final String label;
  final bool selected;
  const _LangTile({required this.code, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected;
    return ListTile(
      leading: isSelected ? const Icon(Icons.radio_button_checked) : const Icon(Icons.radio_button_unchecked),
      title: Text(label),
      onTap: () async {
        final ctrl = context.read<LocaleController>();
        final c = code; // field -> local for promotion
        await ctrl.setLocale(c == null ? null : Locale(c));
        if (context.mounted) Navigator.pop(context);
      },
    );
  }
}
