import 'package:flutter/material.dart';

/// Passive status banner + view toggle.
///
/// No "Organize Now" button — backend handles classification automatically.
/// Shows processing status if unprocessed emails exist, otherwise just the toggle.
class ClassificationBanner extends StatelessWidget {
  final int unprocessedCount;
  final bool isOrganizedView;
  final int totalNotifications;
  final ValueChanged<bool> onViewToggle;

  const ClassificationBanner({
    super.key,
    required this.unprocessedCount,
    required this.isOrganizedView,
    required this.totalNotifications,
    required this.onViewToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (totalNotifications == 0) return const SizedBox.shrink();

    return Column(
      children: [
        // Processing indicator (if any unprocessed emails)
        if (unprocessedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Processing $unprocessedCount email${unprocessedCount == 1 ? '' : 's'}…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // View toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Organized'),
                      icon: Icon(Icons.auto_awesome, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Recent'),
                      icon: Icon(Icons.schedule, size: 16),
                    ),
                  ],
                  selected: <bool>{isOrganizedView},
                  onSelectionChanged: (Set<bool> newSelection) {
                    onViewToggle(newSelection.first);
                  },
                  showSelectedIcon: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
