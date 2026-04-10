import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';

/// Compact timeline widget for sidebar/right-panel display.
/// Shows grouped timeline items (Today, Tomorrow, etc.) in a minimal, readable format.
/// Features: icons, time labels, titles only (no descriptions).
class TimelineCompact extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final void Function(Map<String, dynamic>)? onItemTap;

  const TimelineCompact({
    super.key,
    required this.groups,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(
          'No upcoming items',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups
          .map((group) => _buildCompactGroup(context, group))
          .toList(),
    );
  }

  Widget _buildCompactGroup(
    BuildContext context,
    Map<String, dynamic> group,
  ) {
    final dateLabel = group['date'] as String? ?? 'Upcoming';
    final items = (group['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              dateLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) => _buildCompactItem(context, item)).toList(),
        ],
      ),
    );
  }

  Widget _buildCompactItem(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final title = item['title'] as String? ?? '';
    final timeIso = item['time'] as String?;
    final type = item['type'] as String? ?? 'INFORMATION';

    String timeLabel = '';
    if (timeIso != null) {
      try {
        final dt = DateTime.parse(timeIso).toLocal();
        timeLabel = DateFormat.jm().format(dt);
      } catch (_) {
        timeLabel = '';
      }
    }

    final color = topicColor(type);
    final icon = _iconForType(type);

    return InkWell(
      onTap: onItemTap == null ? null : () => onItemTap!(item),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color dot indicator
            Padding(
              padding: const EdgeInsets.only(top: 4.0, right: 8.0),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'ASSIGNMENT':
        return Icons.assignment;
      case 'EXAM':
        return Icons.event_note;
      case 'ACADEMIC_ADMIN':
        return Icons.info;
      case 'OPPORTUNITY':
        return Icons.lightbulb;
      case 'INFORMATION':
        return Icons.notifications;
      default:
        return Icons.event;
    }
  }
}
