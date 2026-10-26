import 'package:flutter/material.dart';

/// Brand colors come from the firefly icon: warm amber glow on deep navy.
class SignaraTheme {
  static const Color amber = Color(0xFFFFB300);
  static const Color navy = Color(0xFF141A33);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: amber,
          brightness: Brightness.light,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: amber,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: navy,
      );
}
