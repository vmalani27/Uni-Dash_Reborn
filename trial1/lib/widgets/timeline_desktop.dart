import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';

/// Enhanced timeline widget for desktop/tablet side-panel display.
/// More visually prominent than TimelineCompact while maintaining density.
/// Features: type icons, color indicators, time labels, better spacing & typography.
class TimelineDesktop extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final void Function(Map<String, dynamic>)? onItemTap;

  const TimelineDesktop({
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
          .map((group) => _buildDesktopGroup(context, group))
          .toList(),
    );
  }

  Widget _buildDesktopGroup(
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
          // Date header with subtle accent
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  dateLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            return _buildDesktopItem(context, entry.value, isLast);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDesktopItem(
    BuildContext context,
    Map<String, dynamic> item,
    bool isLast,
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

    final meta = academicCategoryMeta(type);
    final color = meta.color;
    final icon = _iconForType(type);

    return Padding(
      padding: EdgeInsets.only(
        left: 10.0,
        bottom: isLast ? 0 : 4.0,
      ),
      child: InkWell(
        onTap: onItemTap == null ? null : () => onItemTap!(item),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Timeline connector circle
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      border: Border.all(
                        color: color.withOpacity(0.4),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 10,
                      color: color,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 1.5,
                      height: 12,
                      color: color.withOpacity(0.15),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              // Content: title and time on same line
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Time combined
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 3),
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ],  // Closes Row children array
                    ),
                    // Type badge (subtle)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(
                            color: color.withOpacity(0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          type.replaceAll('_', ' ').toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
