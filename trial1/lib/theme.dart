import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kBgPrimaryDark = Color(0xFF0A0A0C);
const Color kBgSecondaryDark = Color(0xFF111114);
const Color kBgSurfaceDark = Color(0xFF17171B);
const Color kBgElevatedDark = Color(0xFF1D1E23);
const Color kSidebarDark = Color(0xFF101114);
const Color kTextPrimaryDark = Color(0xFFF5F5F5);
const Color kTextSecondaryDark = Color(0xFFA1A1AA);
const Color kTextTertiaryDark = Color(0xFF71717A);
const Color kBorderSubtleDark = Color(0xFF27272A);
const Color kBorderMediumDark = Color(0xFF3F3F46);

const Color kBgPrimaryLight = Color(0xFFFAF9F7);
const Color kBgSecondaryLight = Color(0xFFF4F1EE);
const Color kBgSurfaceLight = Color(0xFFF7F4F1);
const Color kBgElevatedLight = Color(0xFFEAE6E1);
const Color kSidebarLight = Color(0xFFF6F3EF);
const Color kTextPrimaryLight = Color(0xFF18181B);
const Color kTextSecondaryLight = Color(0xFF52525B);
const Color kTextTertiaryLight = Color(0xFF7C7C86);
const Color kBorderSubtleLight = Color(0xFFD8D2CC);
const Color kBorderMediumLight = Color(0xFFBDB5AE);

const Color kAccentPrimary = Color(0xFF18181B);
const Color kAccentPrimaryDark = Color(0xFFF5F5F5);
const Color kAccentPrimaryLight = Color(0xFF18181B);
const Color kAccentSecondary = Color(0xFF52525B);
const Color kAccentSecondaryLight = Color(0xFF71717A);
const Color kAccentHover = Color(0xFF27272A);
const Color kAccentHoverLight = Color(0xFF3F3F46);

const Color kTopicAssignment = Color(0xFF64748B);
const Color kTopicExam = Color(0xFF334155);
const Color kTopicAcademic = Color(0xFF475569);
const Color kTopicOpportunity = Color(0xFF6B7280);
const Color kTopicInformation = Color(0xFF64748B);
const Color kTopicOther = Color(0xFF6B7280);

const Color kUrgencyCritical = Color(0xFFEF4444);
const Color kUrgencyHigh = Color(0xFFF97316);
const Color kUrgencyMedium = Color(0xFFEAB308);
const Color kUrgencyLow = Color(0xFF22C55E);
const Color kUrgencyNone = Color(0xFF6B7280);

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

  Color tint([double alpha = 0.12]) => color.withValues(alpha: alpha);
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

TextTheme _buildTextTheme() {
  final base = GoogleFonts.interTextTheme();
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(letterSpacing: -0.04),
    displayMedium: base.displayMedium?.copyWith(letterSpacing: -0.03),
    headlineLarge: base.headlineLarge?.copyWith(letterSpacing: -0.03),
    headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -0.02),
    headlineSmall: base.headlineSmall?.copyWith(letterSpacing: -0.01),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
    bodySmall: base.bodySmall?.copyWith(height: 1.45),
    labelLarge: base.labelLarge?.copyWith(letterSpacing: 0.1),
    labelMedium: base.labelMedium?.copyWith(letterSpacing: 0.08),
    labelSmall: base.labelSmall?.copyWith(letterSpacing: 0.06),
  );
}

ThemeData _buildTheme({
  required Brightness brightness,
  required Color background,
  required Color surface,
  required Color elevatedSurface,
  required Color sidebar,
  required Color foreground,
  required Color mutedForeground,
  required Color subtleBorder,
  required Color strongBorder,
  required Color onPrimary,
  required Color primary,
  required Color secondary,
  required Color tertiary,
}) {
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onPrimary,
      tertiary: tertiary,
      onTertiary: onPrimary,
      error: kUrgencyCritical,
      onError: Colors.white,
      surface: surface,
      onSurface: foreground,
      surfaceContainerHighest: elevatedSurface,
      onSurfaceVariant: mutedForeground,
      outline: subtleBorder,
      outlineVariant: strongBorder,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? Colors.white : Colors.black,
      onInverseSurface: isDark ? Colors.black : Colors.white,
      inversePrimary: primary,
    ),
    textTheme: _buildTextTheme().apply(
      bodyColor: foreground,
      displayColor: foreground,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: foreground),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: foreground,
        letterSpacing: -0.02,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: subtleBorder.withValues(alpha: isDark ? 0.75 : 1)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: subtleBorder.withValues(alpha: isDark ? 0.5 : 0.9),
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: elevatedSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: subtleBorder.withValues(alpha: isDark ? 0.7 : 1)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: elevatedSurface,
      contentTextStyle: GoogleFonts.inter(
        color: foreground,
        fontSize: 14,
        height: 1.4,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: mutedForeground,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? elevatedSurface.withValues(alpha: 0.5) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: subtleBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: subtleBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kUrgencyCritical),
      ),
      hintStyle: GoogleFonts.inter(color: mutedForeground),
      labelStyle: GoogleFonts.inter(color: mutedForeground),
    ),
    iconTheme: IconThemeData(color: foreground),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: sidebar,
      selectedIconTheme: IconThemeData(color: foreground, size: 20),
      unselectedIconTheme: IconThemeData(color: mutedForeground, size: 20),
      selectedLabelTextStyle: GoogleFonts.inter(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        color: mutedForeground,
        fontWeight: FontWeight.w500,
      ),
      indicatorColor: primary.withValues(alpha: isDark ? 0.12 : 0.08),
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: sidebar,
      selectedItemColor: foreground,
      unselectedItemColor: mutedForeground,
      selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: elevatedSurface,
      disabledColor: elevatedSurface,
      selectedColor: primary.withValues(alpha: isDark ? 0.18 : 0.12),
      labelStyle: GoogleFonts.inter(color: foreground, fontWeight: FontWeight.w600),
      secondaryLabelStyle: GoogleFonts.inter(color: mutedForeground),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: subtleBorder.withValues(alpha: isDark ? 0.75 : 1)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary.withValues(alpha: isDark ? 0.16 : 0.1);
          }
          return surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return foreground;
          }
          return mutedForeground;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: primary.withValues(alpha: 0.5), width: 1.4);
          }
          return BorderSide(color: subtleBorder);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return mutedForeground;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: isDark ? 0.3 : 0.18);
        }
        return subtleBorder.withValues(alpha: 0.5);
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary;
        }
        return Colors.transparent;
      }),
      side: BorderSide(color: subtleBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: foreground,
      unselectedLabelColor: mutedForeground,
      indicatorColor: foreground,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    dividerColor: subtleBorder.withValues(alpha: isDark ? 0.5 : 0.9),
    disabledColor: mutedForeground,
  );
}

final ThemeData uniDashDarkTheme = _buildTheme(
  brightness: Brightness.dark,
  background: kBgPrimaryDark,
  surface: kBgSurfaceDark,
  elevatedSurface: kBgElevatedDark,
  sidebar: kSidebarDark,
  foreground: kTextPrimaryDark,
  mutedForeground: kTextSecondaryDark,
  subtleBorder: kBorderSubtleDark,
  strongBorder: kBorderMediumDark,
  onPrimary: Colors.black,
  primary: kAccentPrimaryDark,
  secondary: kAccentSecondary,
  tertiary: kAccentHover,
);

final ThemeData uniDashLightTheme = _buildTheme(
  brightness: Brightness.light,
  background: kBgPrimaryLight,
  surface: kBgSurfaceLight,
  elevatedSurface: kBgElevatedLight,
  sidebar: kSidebarLight,
  foreground: kTextPrimaryLight,
  mutedForeground: kTextSecondaryLight,
  subtleBorder: kBorderSubtleLight,
  strongBorder: kBorderMediumLight,
  onPrimary: Colors.white,
  primary: kAccentPrimaryLight,
  secondary: kAccentSecondaryLight,
  tertiary: kAccentHoverLight,
);
