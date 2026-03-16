import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Core Palette ───────────────────────────────────────────
// Dark tokens
const Color kBgPrimaryDark = Color(0xFF0F1115);
const Color kBgSurfaceDark = Color(0xFF171A21);
const Color kBgElevatedDark = Color(0xFF1E222B);
const Color kSidebarDark = Color(0xFF181B22);
const Color kTextPrimaryDark = Color(0xFFE6E6E6);
const Color kTextSecondaryDark = Color(0xFF9CA3AF);
const Color kTextDisabledDark = Color(0xFF6B7280);

// Light tokens
const Color kBgPrimaryLight = Color(0xFFF6F7F9); // page background
const Color kBgSurfaceLight = Color(0xFFFFFFFF); // card background
const Color kBgElevatedLight = Color(0xFFF2F3F7); // raised surface
const Color kSidebarLight = Color(0xFFE9EAEC); // sidebar background
const Color kTextPrimaryLight = Color(0xFF23272F);
const Color kTextSecondaryLight = Color(0xFF5A5F6B);
const Color kTextDisabledLight = Color(0xFFB0B4BE);

const Color kAccentPrimary = Color(0xFFE59A23);
const Color kAccentSecondary = Color(0xFFF4C76B);

// ─── Topic Semantic Colors ──────────────────────────────────
const Color kTopicAssignment = Color(0xFF60A5FA); // blue-400
const Color kTopicExam = Color(0xFFF87171); // red-400
const Color kTopicAcademic = Color(0xFFA78BFA); // violet-400
const Color kTopicOpportunity = Color(0xFF34D399); // emerald-400
const Color kTopicInformation = Color(0xFFFBBF24); // amber-400
const Color kTopicOther = Color(0xFF9CA3AF); // gray-400

// ─── Urgency Colors ─────────────────────────────────────────
const Color kUrgencyCritical = Color(0xFFEF4444);
const Color kUrgencyHigh = Color(0xFFF97316);
const Color kUrgencyMedium = Color(0xFFEAB308);
const Color kUrgencyLow = Color(0xFF22C55E);
const Color kUrgencyNone = Color(0xFF6B7280);

// ─── Helpers ────────────────────────────────────────────────
Color topicColor(String normalizedTopic) {
  switch (normalizedTopic) {
    case 'ASSIGNMENT':
      return kTopicAssignment;
    case 'EXAM':
      return kTopicExam;
    case 'ACADEMIC_ADMIN':
      return kTopicAcademic;
    case 'OPPORTUNITY':
      return kTopicOpportunity;
    case 'INFORMATION':
      return kTopicInformation;
    default:
      return kTopicOther;
  }
}

String topicLabel(String normalizedTopic) {
  switch (normalizedTopic) {
    case 'ASSIGNMENT':
      return 'Assignment';
    case 'EXAM':
      return 'Exam';
    case 'ACADEMIC_ADMIN':
      return 'Academic';
    case 'OPPORTUNITY':
      return 'Opportunity';
    case 'INFORMATION':
      return 'Info';
    case 'UNCLASSIFIED':
      return 'Unclassified';
    default:
      return 'Other';
  }
}

IconData topicIcon(String normalizedTopic) {
  switch (normalizedTopic) {
    case 'ASSIGNMENT':
      return Icons.assignment_outlined;
    case 'EXAM':
      return Icons.quiz_outlined;
    case 'ACADEMIC_ADMIN':
      return Icons.school_outlined;
    case 'OPPORTUNITY':
      return Icons.rocket_launch_outlined;
    case 'INFORMATION':
      return Icons.info_outline;
    default:
      return Icons.mail_outline;
  }
}

Color urgencyColor(String? urgency) {
  switch (urgency) {
    case 'Critical':
      return kUrgencyCritical;
    case 'High':
      return kUrgencyHigh;
    case 'Medium':
      return kUrgencyMedium;
    case 'Low':
      return kUrgencyLow;
    default:
      return kUrgencyNone;
  }
}

// ─── Text Theme ─────────────────────────────────────────────
TextTheme _buildTextTheme() {
  final base = GoogleFonts.interTextTheme();
  // Use colorScheme tokens at usage site, not here. This avoids undefined identifier errors.
  return base;
}

// ─── Dark Theme ─────────────────────────────────────────────
final ThemeData uniDashDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBgPrimaryDark,
  textTheme: GoogleFonts.interTextTheme().apply(
    bodyColor: kTextPrimaryDark,
    displayColor: kTextPrimaryDark,
  ),
  colorScheme: const ColorScheme.dark(
    primary: kAccentPrimary,
    secondary: kAccentSecondary,
    surface: kBgSurfaceDark,
    surfaceVariant: kSidebarDark,
    background: kBgPrimaryDark,
    onPrimary: Colors.black,
    onSurface: kTextPrimaryDark,
    onBackground: kTextPrimaryDark,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: kBgPrimaryDark,
    elevation: 0,
    scrolledUnderElevation: 0,
    iconTheme: const IconThemeData(color: kTextPrimaryDark),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kTextPrimaryDark,
    ),
  ),
  cardTheme: CardThemeData(
    color: kBgSurfaceDark,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: kSidebarDark,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccentPrimary,
      foregroundColor: Colors.black,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kTextSecondaryDark,
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimary.withOpacity(0.15);
        }
        return kBgSurfaceDark;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimary;
        }
        return kTextSecondaryDark;
      }),
      side: WidgetStateProperty.all(
        BorderSide(color: kTextDisabledDark.withOpacity(0.2)),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: kBgElevatedDark,
    contentTextStyle: GoogleFonts.inter(color: kTextPrimaryDark, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
  dividerColor: kTextDisabledDark.withOpacity(0.15),
  disabledColor: kTextDisabledDark,
);

// ─── Light Theme ───────────────────────────────────────────
final ThemeData uniDashLightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: kBgPrimaryLight,
  textTheme: GoogleFonts.interTextTheme().apply(
    bodyColor: kTextPrimaryLight,
    displayColor: kTextPrimaryLight,
  ),
  colorScheme: const ColorScheme.light(
    primary: kAccentPrimary,
    secondary: kAccentSecondary,
    surface: kBgSurfaceLight,
    surfaceVariant: kSidebarLight,
    background: kBgPrimaryLight,
    onPrimary: Colors.black,
    onSurface: kTextPrimaryLight,
    onBackground: kTextPrimaryLight,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: kBgPrimaryLight,
    elevation: 0,
    scrolledUnderElevation: 0,
    iconTheme: const IconThemeData(color: kTextPrimaryLight),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kTextPrimaryLight,
    ),
  ),
  cardTheme: CardThemeData(
    color: kBgSurfaceLight,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: kSidebarLight,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccentPrimary,
      foregroundColor: Colors.black,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kTextSecondaryLight,
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimary.withOpacity(0.10);
        }
        return kBgSurfaceLight;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimary;
        }
        return kTextSecondaryLight;
      }),
      side: WidgetStateProperty.all(
        BorderSide(color: kTextDisabledLight.withOpacity(0.18)),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: kBgElevatedLight,
    contentTextStyle: GoogleFonts.inter(color: kTextPrimaryLight, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),
  dividerColor: kTextDisabledLight.withOpacity(0.13),
  disabledColor: kTextDisabledLight,
);
