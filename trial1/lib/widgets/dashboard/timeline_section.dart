import 'package:flutter/material.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/expandable_tile.dart';
import 'package:intl/intl.dart';

class TimelineSection extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final Function(Map<String, dynamic>) onItemTap;

  const TimelineSection({
    super.key,
    required this.groups,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Timeline',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        ...groups.map((g) => _buildGroup(context, g)),
      ],
    );
  }

  Widget _buildGroup(BuildContext context, Map<String, dynamic> group) {
    final dateLabel = group['date'] as String? ?? 'Upcoming';
    final items = (group['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: ExpandableTile(event: it, onTap: () => onItemTap(it)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const _TimelineEventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String? ?? 'INFORMATION';
    final title = event['title'] as String? ?? '';
    final timeIso = event['time'] as String?;
    String subtitle = '';
    if (timeIso != null) {
      try {
        final dt = DateTime.parse(timeIso).toLocal();
        subtitle = DateFormat.jm().format(dt);
      } catch (_) {
        subtitle = timeIso;
      }
    }
    final color = topicColor(type);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
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
}
