import 'package:flutter/material.dart';

class AppTheme {
  // Koyu mor tonlar, altın detaylarla uyumlu
  static const Color bg = Color(0xFF080311); // temel koyu mor
  static const Color surface = Color(0xFF12051F); // kart / yüzey rengi
  static const Color gold = Color(0xFFD8B982);
  static const Color goldBright = Color(0xFFF3D7A2);
  static const Color muted = Color(0xFFAFA7B8);
  static const Color violet = Color(0xFF9B79F7);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        primaryColor: gold,
        // Tüm sayfaların arkasında yıldızlı görsel görünsün diye Scaffold'u transparan yapıyoruz.
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: violet,
          surface: surface,
          background: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: gold,
        ),
        cardColor: surface,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: goldBright,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          bodyMedium: TextStyle(color: muted),
        ),
      );
}

