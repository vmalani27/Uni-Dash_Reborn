import 'package:flutter/material.dart';
import 'package:trial1/widgets/expandable_tile.dart';

class TimelineSection extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final void Function(Map<String, dynamic>) onItemTap;
  final Future<void> Function(Map<String, dynamic>)? onMarkCompleted;
  final Future<void> Function(Map<String, dynamic>)? onAddToCalendar;
  final Future<void> Function(Map<String, dynamic>)? onDismiss;

  const TimelineSection({
    super.key,
    required this.groups,
    required this.onItemTap,
    this.onMarkCompleted,
    this.onAddToCalendar,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups
          .map((group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TimelineGroupCard(
                  group: group,
                  onItemTap: onItemTap,
                  onMarkCompleted: onMarkCompleted,
                  onAddToCalendar: onAddToCalendar,
                  onDismiss: onDismiss,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        'No upcoming items',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _TimelineGroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final void Function(Map<String, dynamic>) onItemTap;
  final Future<void> Function(Map<String, dynamic>)? onMarkCompleted;
  final Future<void> Function(Map<String, dynamic>)? onAddToCalendar;
  final Future<void> Function(Map<String, dynamic>)? onDismiss;

  const _TimelineGroupCard({
    required this.group,
    required this.onItemTap,
    this.onMarkCompleted,
    this.onAddToCalendar,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = group['date'] as String? ?? 'Upcoming';
    final items = (group['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: ExpandableTile(
                event: entry.value,
                onTap: () => onItemTap(entry.value),
                onMarkCompleted: onMarkCompleted == null ? null : () => onMarkCompleted!(entry.value),
                onAddToCalendar: onAddToCalendar == null ? null : () => onAddToCalendar!(entry.value),
                onDismiss: onDismiss == null ? null : () => onDismiss!(entry.value),
              ),
            );
          }),
        ],
      ),
    );
  }
}
