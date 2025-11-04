import 'package:flutter/material.dart';
import 'fal_hub_page_fixed.dart';
import '../history/history_page.dart';
import '../profile/profile_page.dart';
import 'package:provider/provider.dart';
import '../../core/entitlements/entitlements_controller.dart';
import '../../core/readings/pending_readings_service.dart';
import '../profile/profile_controller.dart';
import '../history/history_controller.dart';
import '../../core/ads/ad_service.dart';
import '../../core/i18n/app_localizations.dart';
import '../live/live_chat_page_fixed.dart';

class HomeShell extends StatefulWidget {
  final int initialIndex;
  const HomeShell({super.key, this.initialIndex = 0});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;
  final pages = const [FalHubPage(), LiveChatPage(), HistoryPage(), ProfilePage()];

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex.clamp(0, pages.length - 1);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final hist = context.read<HistoryController>();
        final prof = context.read<ProfileController>();
        final locale = Localizations.localeOf(context).languageCode;
        await PendingReadingsService.checkAndCompleteDue(history: hist, profile: prof, locale: locale);
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final hist = context.read<HistoryController>();
      final prof = context.read<ProfileController>();
      final locale = Localizations.localeOf(context).languageCode;
      // ignore: unawaited_futures
      PendingReadingsService.checkAndCompleteDue(history: hist, profile: prof, locale: locale);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<EntitlementsController>().isPremium;
    final loc = AppLocalizations.of(context);
    final navFal = loc.t('nav.fal');
    // Rename bottom tab to AI Canlı (or AI Live) to distinguish from
    // the separate "Canlı Falcı" tile on the hub.
    final navLive = (loc.t('nav.live_ai') != 'nav.live_ai')
        ? loc.t('nav.live_ai')
        : (Localizations.localeOf(context).languageCode.startsWith('tr') ? 'AI Canlı' : 'AI Live');
    final navHistory = loc.t('nav.history');
    final navProfile = loc.t('nav.profile');
    const gold = Color(0xFFFFC857); // MystiQ altin tonu
    const unSel = Colors.white70;
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && index != 0) {
          setState(() => index = 0);
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(child: pages[index]),
            if (!isPremium) const AdBanner(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF151019), Color(0xFF0F0D15)],
            ),
            boxShadow: [
              BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, -4)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              showUnselectedLabels: true,
              selectedItemColor: gold,
              unselectedItemColor: unSel,
              selectedIconTheme: const IconThemeData(size: 28),
              unselectedIconTheme: const IconThemeData(size: 24),
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.2),
              currentIndex: index,
              onTap: (i) {
                if (i == 1) {
                  // Keep the tab visible but disable navigation for now
                  final msg = loc.t('common.coming_soon');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  return;
                }
                setState(() => index = i);
              },
              items: [
                BottomNavigationBarItem(
                  icon: _BarIcon(icon: Icons.auto_awesome, active: index == 0, color: gold, inactive: unSel),
                  label: navFal,
                ),
                BottomNavigationBarItem(
                  icon: _BarIcon(icon: Icons.chat_bubble_outline, active: index == 1, color: gold, inactive: unSel),
                  label: navLive,
                ),
                BottomNavigationBarItem(
                  icon: _BarIcon(icon: Icons.history, active: index == 2, color: gold, inactive: unSel),
                  label: navHistory,
                ),
                BottomNavigationBarItem(
                  icon: _BarIcon(icon: Icons.person_outline, active: index == 3, color: gold, inactive: unSel),
                  label: navProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color color;
  final Color inactive;
  const _BarIcon({required this.icon, required this.active, required this.color, required this.inactive});
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active
              ? LinearGradient(
                  colors: [color.withValues(alpha: 0.18), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 10, spreadRadius: 0.5)]
              : const [],
          border: active ? Border.all(color: color.withValues(alpha: 0.5)) : null,
        ),
        child: Icon(icon, color: active ? color : inactive),
      ),
    );
  }
}
