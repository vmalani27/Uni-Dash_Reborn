import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Core Palette ───────────────────────────────────────────
const Color kBgPrimary = Color(0xFF0F1115);
const Color kBgSurface = Color(0xFF171A21);
const Color kBgElevated = Color(0xFF1E222B);

const Color kTextPrimary = Color(0xFFE6E6E6);
const Color kTextSecondary = Color(0xFF9CA3AF);
const Color kTextDisabled = Color(0xFF6B7280);

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
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: kTextPrimary,
      letterSpacing: -0.5,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 15,
      height: 1.5,
      color: kTextSecondary,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      height: 1.5,
      color: kTextSecondary,
    ),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12, color: kTextDisabled),
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: kTextSecondary,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: kTextDisabled,
      letterSpacing: 0.3,
    ),
  );
}

// ─── Dark Theme ─────────────────────────────────────────────
final ThemeData uniDashDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kBgPrimary,
  textTheme: _buildTextTheme(),

  colorScheme: const ColorScheme.dark(
    primary: kAccentPrimary,
    secondary: kAccentSecondary,
    surface: kBgSurface,
    onPrimary: Colors.black,
    onSurface: kTextPrimary,
  ),

  appBarTheme: AppBarTheme(
    backgroundColor: kBgPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    iconTheme: const IconThemeData(color: kTextPrimary),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: kTextPrimary,
    ),
  ),

  cardTheme: CardThemeData(
    color: kBgSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
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
      foregroundColor: kTextSecondary,
      textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
    ),
  ),

  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimary.withOpacity(0.15);
        }
        return kBgSurface;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimary;
        }
        return kTextSecondary;
      }),
      side: WidgetStateProperty.all(
        BorderSide(color: kTextDisabled.withOpacity(0.2)),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  ),

  snackBarTheme: SnackBarThemeData(
    backgroundColor: kBgElevated,
    contentTextStyle: GoogleFonts.inter(color: kTextPrimary, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  ),

  dividerColor: kTextDisabled.withOpacity(0.15),
  disabledColor: kTextDisabled,
);

// ─── Light Theme (minimal) ──────────────────────────────────
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
