import 'package:flutter/material.dart';
import '../../core/notifications/notifications_service.dart';
import '../../core/i18n/app_localizations.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});
  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  bool enabled = false;
  @override
  void initState() {
    super.initState();
    NotificationsService.isDailyEnabled().then((v) => setState(() => enabled = v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).t('notifications.title'))),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(AppLocalizations.of(context).t('notifications.daily_energy')),
            value: enabled,
            onChanged: (v) async {
              await NotificationsService.setDailyEnabled(v);
              setState(() => enabled = v);
            },
          ),
          const Divider(height: 1),
          ListTile( leading: const Icon(Icons.campaign_outlined), title: Text(AppLocalizations.of(context).t('notifications.promos_title')), subtitle: Text(AppLocalizations.of(context).t('notifications.promos_subtitle')), )
        ],
      ),
    );
  }
}


