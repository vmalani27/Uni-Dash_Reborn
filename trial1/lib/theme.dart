import 'package:flutter/material.dart';

const Color kBgPrimary = Color(0xFF0F1115); // main background
const Color kBgSurface = Color(0xFF171A21); // cards, dialogs
const Color kBgElevated = Color(0xFF1E222B); // modals, sheets

const Color kTextPrimary = Color(0xFFE6E6E6);
const Color kTextSecondary = Color(0xFFB3B3B3);
const Color kTextDisabled = Color(0xFF7A7A7A);

const Color kAccentPrimary = Color(0xFFE59A23); // amber

final ThemeData uniDashDarkTheme = ThemeData(
  brightness: Brightness.dark,

  scaffoldBackgroundColor: kBgPrimary,

  colorScheme: const ColorScheme.dark(
    primary: kAccentPrimary,
    surface: kBgSurface,
    onPrimary: Colors.black,
    onSurface: kTextPrimary,
  ),

  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: kTextSecondary),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: kTextSecondary),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: kBgPrimary,
    elevation: 0,
    iconTheme: IconThemeData(color: kTextPrimary),
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
  ),

  cardTheme: CardThemeData(
    color: kBgSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccentPrimary,
      foregroundColor: Colors.black,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kTextSecondary,
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
    ),
  ),

  dividerColor: kTextDisabled.withOpacity(0.2),
  disabledColor: kTextDisabled,
);

final ThemeData uniDashLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF6F7F9),

  colorScheme: ColorScheme.light(
    primary: kAccentPrimary,
    surface: Colors.white,
    onPrimary: Colors.black,
    onSurface: Colors.black87,
  ),

  textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black87)),
);
