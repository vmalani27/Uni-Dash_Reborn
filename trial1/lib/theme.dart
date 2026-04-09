import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Core Palette ───────────────────────────────────────────
// DARK MODE TOKENS
const Color kBgPrimaryDark = Color(0xFF0F1115);       // page bg
const Color kBgSecondaryDark = Color(0xFF171A21);     // nested bg
const Color kBgSurfaceDark = Color(0xFF1E222B);       // cards
const Color kBgElevatedDark = Color(0xFF272D38);      // raised surfaces
const Color kSidebarDark = Color(0xFF181B22);         // sidebar
const Color kTextPrimaryDark = Color(0xFFE6E6E6);
const Color kTextSecondaryDark = Color(0xFF9CA3AF);
const Color kTextTertiaryDark = Color(0xFF6B7280);
const Color kBorderSubtleDark = Color(0xFF404854);    // light dividers
const Color kBorderMediumDark = Color(0xFF505866);    // active states
const Color kBorderStrongDark = Color(0xFF646F85);    // focus states

// LIGHT MODE TOKENS
const Color kBgPrimaryLight = Color(0xFFFFFFFF);      // page bg (pure white)
const Color kBgSecondaryLight = Color(0xFFF9FAFB);    // nested bg
const Color kBgSurfaceLight = Color(0xFFF3F4F6);      // cards (light gray)
const Color kBgElevatedLight = Color(0xFFE5E7EB);     // raised surfaces
const Color kSidebarLight = Color(0xFFF3F4F6);        // sidebar
const Color kTextPrimaryLight = Color(0xFF1F2937);    // darker text
const Color kTextSecondaryLight = Color(0xFF4B5563);  // secondary
const Color kTextTertiaryLight = Color(0xFF9CA3AF);   // disabled
const Color kBorderSubtleLight = Color(0xFFD1D5DB);   // visible borders
const Color kBorderMediumLight = Color(0xFF9CA3AF);   // active borders
const Color kBorderStrongLight = Color(0xFF6B7280);   // focus borders

// ACCENT COLORS
const Color kAccentPrimary = Color(0xFF4F46E5);       // indigo
const Color kAccentPrimaryDark = Color(0xFF4F46E5);   // indigo
const Color kAccentPrimaryLight = Color(0xFF4F46E5);  // indigo
const Color kAccentSecondary = Color(0xFF6366F1);     // indigo lighter
const Color kAccentSecondaryLight = Color(0xFF4338CA); // indigo darker
const Color kAccentHover = Color(0xFF4338CA);         // indigo interaction
const Color kAccentHoverLight = Color(0xFF3730A3);    // indigo interaction
const Color kAccentFocus = Color(0xFF3730A3);         // indigo focus
const Color kAccentFocusLight = Color(0xFF312E81);    // indigo focus

// ─── Topic Semantic Colors ──────────────────────────────────
// Entity / topic semantic colors (same in both modes for consistency)
const Color kTopicAssignment = Color(0xFF64748B);    // slate
const Color kTopicExam = Color(0xFF64748B);          // slate
const Color kTopicAcademic = Color(0xFF64748B);      // slate
const Color kTopicOpportunity = Color(0xFF64748B);   // slate
const Color kTopicInformation = Color(0xFF64748B);   // slate
const Color kTopicOther = Color(0xFF64748B);         // slate

// ─── Urgency Colors ─────────────────────────────────────────
const Color kUrgencyCritical = Color(0xFFEF4444);
const Color kUrgencyHigh = Color(0xFFF97316);
const Color kUrgencyMedium = Color(0xFFEAB308);
const Color kUrgencyLow = Color(0xFF22C55E);
const Color kUrgencyNone = Color(0xFF6B7280);

// ─── Helpers ────────────────────────────────────────────────
class AcademicCategoryMeta {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const AcademicCategoryMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  Color tint([double alpha = 0.12]) => color.withOpacity(alpha);
}

AcademicCategoryMeta academicCategoryMeta(String normalizedTopic) {
  final key = normalizedTopic.trim().toUpperCase();
  switch (key) {
    case 'ASSIGNMENT':
      return const AcademicCategoryMeta(
        key: 'ASSIGNMENT',
        label: 'Assignment',
        icon: Icons.assignment_outlined,
        color: kTopicAssignment,
      );
    case 'EXAM':
      return const AcademicCategoryMeta(
        key: 'EXAM',
        label: 'Exam',
        icon: Icons.school_outlined,
        color: kTopicExam,
      );
    case 'ACADEMIC_ADMIN':
    case 'ACADEMIC':
      return const AcademicCategoryMeta(
        key: 'ACADEMIC_ADMIN',
        label: 'Announcement',
        icon: Icons.campaign_outlined,
        color: kTopicAcademic,
      );
    case 'OPPORTUNITY':
      return const AcademicCategoryMeta(
        key: 'OPPORTUNITY',
        label: 'Opportunity',
        icon: Icons.rocket_launch_outlined,
        color: kTopicOpportunity,
      );
    case 'INFORMATION':
    case 'INFO':
      return const AcademicCategoryMeta(
        key: 'INFORMATION',
        label: 'Info',
        icon: Icons.info_outline,
        color: kTopicInformation,
      );
    default:
      return AcademicCategoryMeta(
        key: key.isEmpty ? 'OTHER' : key,
        label: _fallbackTopicLabel(key),
        icon: _fallbackTopicIcon(key),
        color: kTopicOther,
      );
  }
}

Color topicColor(String normalizedTopic) {
  return academicCategoryMeta(normalizedTopic).color;
}

String topicLabel(String normalizedTopic) {
  final meta = academicCategoryMeta(normalizedTopic);
  if (meta.key == 'OTHER') {
    final s = normalizedTopic.trim();
    if (s.isEmpty) return 'Other';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
  if (meta.key == 'UNCLASSIFIED') return 'Unclassified';
  return meta.label;
}

IconData topicIcon(String normalizedTopic) {
  return academicCategoryMeta(normalizedTopic).icon;
}

String _fallbackTopicLabel(String key) {
  if (key.isEmpty) return 'Other';
  if (key == 'UNCLASSIFIED') return 'Unclassified';

  final words = key.replaceAll('_', ' ').split(RegExp(r'\s+'));
  final titleCased = words
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
  return titleCased.isEmpty ? 'Other' : titleCased;
}

IconData _fallbackTopicIcon(String key) {
  if (key.isEmpty) return Icons.mail_outline;
  return Icons.mail_outline;
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
    primary: kAccentPrimaryDark,
    secondary: kAccentSecondary,
    tertiary: kAccentHover,
    surface: kBgSurfaceDark,
    surfaceContainer: kBgElevatedDark,
    surfaceContainerHighest: kSidebarDark,
    onPrimary: Colors.black,
    onSurface: kTextPrimaryDark,
    onSurfaceVariant: kTextSecondaryDark,
    outline: kBorderSubtleDark,
    outlineVariant: kBorderMediumDark,
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
    color: kBgElevatedDark,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
  ),
  drawerTheme: const DrawerThemeData(backgroundColor: kSidebarDark),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccentPrimaryDark,
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
          return kAccentPrimaryDark.withOpacity(0.15);
        }
        return kBgSurfaceDark;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimaryDark;
        }
        return kTextSecondaryDark;
      }),
      side: WidgetStateProperty.all(
        BorderSide(color: kBorderSubtleDark.withOpacity(0.5)),
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
  dividerColor: kBorderSubtleDark.withOpacity(0.4),
  disabledColor: kTextTertiaryDark,
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
    primary: kAccentPrimaryLight,
    secondary: kAccentSecondaryLight,
    tertiary: kAccentHoverLight,
    surface: kBgSurfaceLight,
    surfaceContainer: kBgElevatedLight,
    surfaceContainerHighest: kSidebarLight,
    onPrimary: Colors.white,
    onSurface: kTextPrimaryLight,
    onSurfaceVariant: kTextSecondaryLight,
    outline: kBorderSubtleLight,
    outlineVariant: kBorderMediumLight,
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: kBorderSubtleLight, width: 1),
    ),
    margin: EdgeInsets.zero,
  ),
  drawerTheme: const DrawerThemeData(backgroundColor: kSidebarLight),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kAccentPrimaryLight,
      foregroundColor: Colors.white,
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
          return kAccentPrimaryLight.withOpacity(0.12);
        }
        return kBgSurfaceLight;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return kAccentPrimaryLight;
        }
        return kTextSecondaryLight;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const BorderSide(color: kAccentPrimaryLight, width: 2);
        }
        return const BorderSide(color: kBorderSubtleLight, width: 1);
      }),
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
  dividerColor: kBorderSubtleLight.withOpacity(0.6),
  disabledColor: kTextTertiaryLight,
);
