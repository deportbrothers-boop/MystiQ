import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../core/notifications/notifications_service.dart';
import '../../core/i18n/app_localizations.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  int index = 0;

  void _next() {
    if (index < 2) {
      controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _askNotificationsThenGo();
    }
  }

  void _askNotificationsThenGo() async {
    final loc = AppLocalizations.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.t('onb.notifications_title')),
        content: Text(loc.t('onb.notifications_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.t('common.no'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(loc.t('common.yes'))),
        ],
      ),
    );
    try {
      if (res == true) {
        await NotificationsService.setDailyEnabled(true);
      }
    } catch (_) {
      // izin/schedule hatası akışı durdurmasın
    } finally {
      if (mounted) context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (i) => setState(() => index = i),
                children: [
                  _Slide(title: loc.t('onb.1.title'), text: loc.t('onb.1.text')),
                  _Slide(title: loc.t('onb.2.title'), text: loc.t('onb.2.text')),
                  _Slide(title: loc.t('onb.3.title'), text: loc.t('onb.3.text')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => context.go('/auth'),
                    child: Text(loc.t('onb.skip')),
                  ),
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(index < 2 ? loc.t('onb.next') : loc.t('onb.start')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final String title;
  final String text;
  const _Slide({required this.title, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 64),
          const SizedBox(height: 24),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

