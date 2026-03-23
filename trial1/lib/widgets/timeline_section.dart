import 'package:flutter/material.dart';

class TimelineSection extends StatelessWidget {
  const TimelineSection({super.key});

  Widget _buildTimelineRow(
    BuildContext context,
    IconData icon,
    String title,
    String time, {
    Color? accent,
  }) {
    final lineColor = Theme.of(context).dividerColor.withOpacity(0.5);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (accent ?? Theme.of(context).colorScheme.primary)
                      .withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: accent ?? Theme.of(context).colorScheme.primary,
                ),
              ),
              Container(width: 2, height: 48, color: lineColor),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Today group
        Text(
          'Today',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        _buildTimelineRow(
          context,
          Icons.event_available_outlined,
          'Assignment reminder',
          'Today, 1:30 PM',
          accent: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),

        // Tomorrow group
        Text(
          'Tomorrow',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        _buildTimelineRow(
          context,
          Icons.school_outlined,
          'Exam',
          'Tomorrow, 10:00 AM',
          accent: Theme.of(context).colorScheme.secondary,
        ),
      ],
    );
  }
}
