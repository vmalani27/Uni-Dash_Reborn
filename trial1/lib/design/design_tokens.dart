import 'package:flutter/material.dart';

class UniTokens {
  static const Color zinc50 = Color(0xFFF4F4F5);
  static const Color zinc100 = Color(0xFFE4E4E7);
  static const Color zinc200 = Color(0xFFD4D4D8);
  static const Color zinc300 = Color(0xFFA1A1AA);
  static const Color zinc400 = Color(0xFF71717A);
  static const Color zinc500 = Color(0xFF52525B);
  static const Color zinc600 = Color(0xFF3F3F46);
  static const Color zinc700 = Color(0xFF27272A);
  static const Color zinc800 = Color(0xFF18181B);
  static const Color zinc900 = Color(0xFF171717);
  static const Color zinc950 = Color(0xFF0A0A0A);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color lightForeground = Color(0xFF171717);
  static const Color darkForeground = Color(0xFFEDEDED);

  static const double cardRadius = 14;
  static const double itemRadius = 12;
  static const double sidebarWidth = 280;

  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? UniTokens.darkBackground : UniTokens.lightBackground;
  final foreground = isDark ? UniTokens.darkForeground : UniTokens.lightForeground;
  final card = isDark ? const Color(0xFF111113) : const Color(0xFFF8F8F9);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: foreground,
    onPrimary: background,
    secondary: isDark ? UniTokens.zinc300 : UniTokens.zinc700,
    onSecondary: background,
    error: const Color(0xFFB91C1C),
    onError: Colors.white,
    surface: background,
    onSurface: foreground,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    cardColor: card,
    dividerColor: isDark ? UniTokens.zinc800 : UniTokens.zinc200,
  );
}
