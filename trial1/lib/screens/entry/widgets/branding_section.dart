import 'package:flutter/material.dart';
import '../../../theme.dart';
import 'feature_list.dart';

class BrandingSection extends StatelessWidget {
  const BrandingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 900;
    final isMobile = screenWidth < 600;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 32 : 48,
        horizontal: isMobile ? 16 : 24,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kBgSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(Icons.auto_awesome, color: kAccentPrimary, size: 36),
            ),
          ),
          SizedBox(height: isMobile ? 24 : 36),
          Text(
            'UniDash',
            style: theme.textTheme.displayLarge?.copyWith(
                  color: kTextPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  fontSize: isMobile ? 36 : 44,
                ),
            textAlign: isNarrow ? TextAlign.center : TextAlign.left,
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            'AI Academic Assistant',
            style: theme.textTheme.titleMedium?.copyWith(
                  color: kAccentPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 16 : 20,
                ),
            textAlign: isNarrow ? TextAlign.center : TextAlign.left,
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            'Turn your university emails into organized, actionable insights. Stay focused, never miss a deadline.',
            style: theme.textTheme.bodyLarge?.copyWith(
                  color: kTextSecondary.withOpacity(0.85),
                  fontSize: isMobile ? 15 : 17,
                  height: 1.6,
                ),
            textAlign: isNarrow ? TextAlign.center : TextAlign.left,
          ),
          SizedBox(height: isMobile ? 20 : 28),
          // Divider (hide on very small screens)
          if (!isMobile)
            Divider(
              color: kBgElevated.withOpacity(0.5),
              thickness: 1,
              endIndent: isNarrow ? 0 : 120,
            ),
          SizedBox(height: isMobile ? 16 : 18),
          // Feature highlights (hide on very small mobile screens)
          if (!isMobile) const FeatureList(),
        ],
      ),
    );
  }
}
