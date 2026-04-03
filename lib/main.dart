import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_router.dart';
import 'theme/app_theme.dart';
import 'core/entitlements/entitlements_controller.dart';
import 'features/history/history_controller.dart';
import 'core/rewards/rewards_controller.dart';
import 'features/profile/profile_controller.dart';
import 'core/ads/ad_service.dart';
import 'core/ads/consent_helper.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_controller.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/notifications/notifications_service.dart';
import 'core/readings/pending_readings_service_fixed.dart';
import 'core/ai/ai_service.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Log uncaught errors instead of crashing on some devices
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError: \n${details.exceptionAsString()}');
    };

    // Don't block first frame for Firebase; initialize with a short timeout, else continue.
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 1));
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    } catch (e) {
      debugPrint('Firebase init (deferred): $e');
      // Try again in background after first frame
      // ignore: unawaited_futures
      Future.microtask(() async {
        try {
          await Firebase.initializeApp();
          FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
        } catch (_) {}
      });
    }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    AiService.configure();
    // Ask for ad consent if required (EEA/UK). Do not block startup on failure.
    try { await AdConsent.requestIfRequired(); } catch (_) {}
    await AdService.init();
    // Fire-and-forget notifications init
    // ignore: unawaited_futures
    NotificationsService.init()
        .then((_) => NotificationsService.touchAndScheduleInactivityReminder())
        .catchError((e){ debugPrint('Notifications init failed: $e'); });
    // Daily notification, sadece kullanici acarsa NotificationCenter/onboarding tarafindan ayarlanir.

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

    runApp(FallaApp(
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

class FallaApp extends StatelessWidget {
  final EntitlementsController entitlements;
  final HistoryController history;
  final LocaleController locale;
  final RewardsController rewards;
  final ProfileController profile;
  const FallaApp({super.key, required this.entitlements, required this.history, required this.locale, required this.rewards, required this.profile});

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
      ],
      child: Consumer<LocaleController>(
        builder: (context, lc, _) => MaterialApp.router(
          title: 'Falla',
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
          builder: (context, child) {
            final app = DecoratedBox(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg/bgfal_hub_starry_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );

            if (!kDebugMode) return app;

            return Stack(
              children: [
                app,
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: SafeArea(
                    child: FloatingActionButton.extended(
                      heroTag: 'testCrash',
                      onPressed: () {
                        if (kDebugMode) {
                          throw Exception('Test Crash');
                        }
                      },
                      icon: const Icon(Icons.bug_report),
                      label: const Text('Test Crash'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Thin, right-to-left scrolling caption used for the global disclaimer
// Disclaimer marquee removed per request

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
      // 24 saat açılmazsa hatırlatma bildirimi planla
      // ignore: unawaited_futures
      NotificationsService.touchAndScheduleInactivityReminder()
          .catchError((e){ debugPrint('Inactivity notif schedule failed: $e'); });
      // ignore: unawaited_futures
      PendingReadingsService.checkAndCompleteDue(history: history, profile: profile)
          .catchError((e){ debugPrint('Pending check (resume) failed: $e'); });
    } else if (state == AppLifecycleState.paused) {
      // Uygulamadan çıkışta (arka plana alınca) tekrar planla
      // ignore: unawaited_futures
      NotificationsService.touchAndScheduleInactivityReminder()
          .catchError((e){ debugPrint('Inactivity notif schedule failed: $e'); });
    }
    super.didChangeAppLifecycleState(state);
  }
}
