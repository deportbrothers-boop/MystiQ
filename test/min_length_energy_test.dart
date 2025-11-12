import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../lib/core/i18n/app_localizations.dart';
import '../lib/core/entitlements/entitlements_controller.dart';
import '../lib/features/readings/common/reading_result_page2.dart';

void main() {
  Widget _wrap(Widget child, {Locale? locale, int energy = 70}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final e = EntitlementsController();
          e.energy = energy;
          return e;
        }),
      ],
      child: MaterialApp(
        locale: locale ?? const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('es'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ensureMinLength appends energy hint when short', (tester) async {
    String? result;
    await tester.pumpWidget(_wrap(Builder(
      builder: (ctx) {
        result = ensureMinLengthForTest(ctx, 'coffee', 'kısa');
        return const SizedBox.shrink();
      },
    ), energy: 30));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.length, greaterThan('kısa'.length));
    // Look for a known Turkish token from energy.generic.low
    expect(result!.toLowerCase(), contains('enerji'));
  });

  testWidgets('ensureMinLength uses locale i18n', (tester) async {
    String? result;
    await tester.pumpWidget(_wrap(Builder(
      builder: (ctx) {
        result = ensureMinLengthForTest(ctx, 'coffee', 'short');
        return const SizedBox.shrink();
      },
    ), locale: const Locale('en'), energy: 90));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.toLowerCase(), anyOf(contains('high energy'), contains('bold')));
  });
}
