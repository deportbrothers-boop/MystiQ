import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_router.dart';
import 'theme/app_theme.dart';
import 'core/entitlements/entitlements_controller.dart';
import 'features/history/history_controller.dart';
import 'core/rewards/rewards_controller.dart';
import 'features/profile/profile_controller.dart';
import 'core/ads/ad_service.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/notifications/notifications_service.dart';
import 'core/readings/pending_readings_service.dart';
import 'core/ai/ai_service.dart';
import 'features/auth/verify_controller.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Don't block first frame for Firebase; initialize with a short timeout, else continue.
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Firebase init (deferred): $e');
      // Try again in background after first frame
      // ignore: unawaited_futures
      Future.microtask(() async {
        try { await Firebase.initializeApp(); } catch (_) {}
      });
    }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Log uncaught errors instead of crashing on some devices
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError: \n${details.exceptionAsString()}');
    };
    AiService.configure();
    AdService.init();
    // Fire-and-forget notifications init
    // ignore: unawaited_futures
    NotificationsService.init().catchError((e){ debugPrint('Notifications init failed: $e'); });

    final entitlements = EntitlementsController();
    final history = HistoryController();
    final locale = LocaleController();
    final rewards = RewardsController();
    final profile = ProfileController();

    entitlements.load();
    history.load();
    locale.load();
    rewards.load();
    profile.load();
    // Defer non-critical async tasks to after first frame to reduce startup latency
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: unawaited_futures
      PendingReadingsService.checkAndCompleteDue(history: history, profile: profile)
          .catchError((e){ debugPrint('Pending check failed: $e'); });
      // ignore: unawaited_futures
      entitlements.ensureDailyEnergyRefresh()
          .catchError((e){ debugPrint('Daily refresh failed: $e'); });
    });

    // App lifecycle: on resume, check pending and complete if due
    final _lifecycle = _PendingLifecycleHook(history: history, profile: profile);
    WidgetsBinding.instance.addObserver(_lifecycle);

    // Optional: grant coins via --dart-define=DEV_GRANT_COINS=10000
    const devGrant = String.fromEnvironment('DEV_GRANT_COINS');
    final grantVal = int.tryParse(devGrant);
    if (grantVal != null && grantVal > 0) {
      // No await; we want app to boot instantly
      // ignore: unawaited_futures
      entitlements.addCoins(grantVal);
    }

    runApp(MystiQApp(
      entitlements: entitlements,
      history: history,
      locale: locale,
      rewards: rewards,
      profile: profile,
    ));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
  });
}

class MystiQApp extends StatelessWidget {
  final EntitlementsController entitlements;
  final HistoryController history;
  final LocaleController locale;
  final RewardsController rewards;
  final ProfileController profile;
  const MystiQApp({super.key, required this.entitlements, required this.history, required this.locale, required this.rewards, required this.profile});

  @override
  Widget build(BuildContext context) {
    // Uygulama genelinde Android overscroll parlamasını (yeşil çizgi) kaldır.
    const scrollBehavior = _NoGlowScrollBehavior();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: entitlements),
        ChangeNotifierProvider.value(value: history),
        ChangeNotifierProvider.value(value: locale),
        ChangeNotifierProvider.value(value: rewards),
        ChangeNotifierProvider.value(value: profile),
        ChangeNotifierProvider(create: (_) => VerifyController()),
      ],
      child: Consumer<LocaleController>(
        builder: (context, lc, _) => MaterialApp.router(
          title: 'MystiQ',
          theme: AppTheme.dark,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          locale: lc.locale,
          scrollBehavior: scrollBehavior,
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('es'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}

// Tüm platformlarda overscroll glow/edge efektini devre dışı bırakır.
class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _PendingLifecycleHook extends WidgetsBindingObserver {
  final HistoryController history;
  final ProfileController profile;
  _PendingLifecycleHook({required this.history, required this.profile});
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: unawaited_futures
      PendingReadingsService.checkAndCompleteDue(history: history, profile: profile)
          .catchError((e){ debugPrint('Pending check (resume) failed: $e'); });
    }
    super.didChangeAppLifecycleState(state);
  }
}
