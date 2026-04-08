import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/i18n/app_localizations.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/auth/signin_page.dart';
import 'features/auth/signup_page.dart';
import 'features/home/home_shell.dart';
import 'features/legal/legal_warning_page.dart';
import 'features/premium/paywall_page.dart';
import 'features/readings/coffee/coffee_page_fixed.dart';
import 'features/readings/tarot/tarot_page.dart';
import 'features/readings/palm/palm_page.dart';
import 'features/readings/common/reading_result_page2.dart';
import 'features/history/history_entry.dart';
import 'features/settings/settings_page.dart';
import 'features/notifications/notification_center_page.dart';
import 'features/analytics/analytics_page.dart';
import 'features/readings/astro/astro_page.dart';
import 'features/readings/dream/dream_page.dart';
import 'features/profile/edit_profile_page.dart';
import 'features/home/motivation_page.dart';

String _legalWarningLocation(String nextRoute) =>
    '/legal-warning?next=${Uri.encodeComponent(nextRoute)}';

Future<String> _resolveInitialLocation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    if (!remember && user != null) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      user = null;
    }

    final nextRoute = (remember && user != null) ? '/home' : '/auth';
    final accepted = prefs.getBool(kLegalWarningAcceptedKey) ?? false;
    if (!accepted) {
      return _legalWarningLocation(nextRoute);
    }
    return nextRoute;
  } catch (_) {
    return '/auth';
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, __) async => await _resolveInitialLocation(),
    ),
    GoRoute(
      path: '/legal-warning',
      redirect: (_, state) async {
        final prefs = await SharedPreferences.getInstance();
        final accepted = prefs.getBool(kLegalWarningAcceptedKey) ?? false;
        if (!accepted) return null;
        final nextRoute = state.uri.queryParameters['next'];
        if (nextRoute != null && nextRoute.startsWith('/')) {
          return nextRoute;
        }
        return '/auth';
      },
      builder: (_, state) => LegalWarningPage(
        nextRoute: state.uri.queryParameters['next'] ?? '/auth',
      ),
    ),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    GoRoute(path: '/auth', builder: (_, __) => const SignInPage()),
    GoRoute(path: '/auth/signup', builder: (_, __) => const SignUpPage()),
    GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    GoRoute(
        path: '/live', builder: (_, __) => const HomeShell(initialIndex: 1)),
    GoRoute(path: '/paywall', builder: (_, __) => const PaywallPage()),
    GoRoute(path: '/reading/coffee', builder: (_, __) => const CoffeePage()),
    GoRoute(path: '/reading/tarot', builder: (_, __) => const TarotPage()),
    GoRoute(path: '/reading/palm', builder: (_, __) => const PalmPage()),
    GoRoute(path: '/reading/astro', builder: (_, __) => const AstroPage()),
    GoRoute(path: '/reading/dream', builder: (_, __) => const DreamPage()),
    GoRoute(path: '/motivation', builder: (_, __) => const MotivationPage()),
    GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfilePage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationCenterPage()),
    GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsPage()),
    GoRoute(
      path: '/reading/result/:type',
      builder: (_, state) {
        final type = state.pathParameters['type'] ?? 'coffee';
        final extra = state.extra;
        if (extra is HistoryEntry) {
          return ReadingResultPage(type: type, providedText: extra.text);
        }
        if (extra is Map<String, dynamic>) {
          return ReadingResultPage(type: type, requestExtras: extra);
        }
        return ReadingResultPage(type: type);
      },
    ),
  ],
  errorBuilder: (ctx, state) => Scaffold(
    body: Center(
      child: Text(
        '${AppLocalizations.of(ctx).t('router.not_found_prefix')} ${state.uri}',
      ),
    ),
  ),
);
