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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Logo
        Container(
          width: isMobile ? 44 : 56,
          height: isMobile ? 44 : 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(Icons.auto_awesome,
                color: Theme.of(context).colorScheme.primary,
                size: isMobile ? 28 : 36),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 36),
        Text(
          'UniDash',
          style: theme.textTheme.displayLarge?.copyWith(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            fontSize: isMobile ? 32 : 44,
          ),
          textAlign: isNarrow ? TextAlign.center : TextAlign.left,
        ),
        SizedBox(height: isMobile ? 4 : 12),
        Text(
          'AI Academic Assistant',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 14 : 20,
          ),
          textAlign: isNarrow ? TextAlign.center : TextAlign.left,
        ),
        SizedBox(height: isMobile ? 10 : 24),
        Text(
          'Turn your university emails into organized, actionable insights. Stay focused, never miss a deadline.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
            fontSize: isMobile ? 14 : 17,
            height: 1.5,
          ),
          textAlign: isNarrow ? TextAlign.center : TextAlign.left,
        ),
        if (!isMobile) ...[
          const SizedBox(height: 28),
          Divider(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            thickness: 1,
            endIndent: isNarrow ? 0 : 120,
          ),
          const SizedBox(height: 18),
          const FeatureList(),
        ],
      ],
    );
  }
}