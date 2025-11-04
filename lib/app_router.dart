import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/splash/splash_page.dart';
import 'core/i18n/app_localizations.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/auth/auth_page.dart';
import 'features/auth/verify_page.dart';
import 'features/auth/signup_page.dart';
import 'features/home/home_shell.dart';
import 'features/premium/paywall_page.dart';
import 'features/readings/coffee/coffee_page_fixed.dart';
import 'features/readings/tarot/tarot_page.dart';
import 'features/readings/palm/palm_page.dart';
import 'features/readings/common/reading_result_page_fixed.dart';
import 'features/history/history_entry.dart';
import 'features/settings/settings_page.dart';
import 'features/notifications/notification_center_page.dart';
import 'features/analytics/analytics_page.dart';
import 'features/readings/astro/astro_page.dart';
import 'features/readings/dream/dream_page.dart';
import 'features/profile/edit_profile_page.dart';
import 'features/home/motivation_page.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    GoRoute(path: '/auth', builder: (_, __) => const AuthPage()),
    GoRoute(path: '/auth/signup', builder: (_, __) => const SignUpPage()),
    GoRoute(path: '/auth/verify', builder: (_, __) => const VerifyPage()),
    GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    GoRoute(path: '/live', builder: (_, __) => const HomeShell(initialIndex: 1)),
    GoRoute(path: '/paywall', builder: (_, __) => const PaywallPage()),
    GoRoute(path: '/reading/coffee', builder: (_, __) => const CoffeePage()),
    GoRoute(path: '/reading/tarot', builder: (_, __) => const TarotPage()),
    GoRoute(path: '/reading/palm', builder: (_, __) => const PalmPage()),
    GoRoute(path: '/reading/astro', builder: (_, __) => const AstroPage()),
    GoRoute(path: '/reading/dream', builder: (_, __) => const DreamPage()),
    GoRoute(path: '/motivation', builder: (_, __) => const MotivationPage()),
    GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfilePage()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationCenterPage()),
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

