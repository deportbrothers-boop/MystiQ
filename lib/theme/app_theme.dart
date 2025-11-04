import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg = Color(0xFF0B0A0E);
  static const Color surface = Color(0xFF121018);
  static const Color gold = Color(0xFFD8B982);
  static const Color goldBright = Color(0xFFF3D7A2);
  static const Color muted = Color(0xFFAFA7B8);
  static const Color violet = Color(0xFF9B79F7);

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        primaryColor: gold,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: violet,
          surface: bg,
        ),
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent, // M3 kartlardaki ince tint/çerçeveyi kapat
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

