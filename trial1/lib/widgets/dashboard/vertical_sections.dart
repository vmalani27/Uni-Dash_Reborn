import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';

class VerticalSections extends StatelessWidget {
  final Map<String, List<AcademicItem>> groups;

  const VerticalSections({super.key, required this.groups});

  static const _order = ['ASSIGNMENT', 'EXAM', 'ACADEMIC_ADMIN', 'OPPORTUNITY'];

  String _labelFor(String key) {
    switch (key) {
      case 'ASSIGNMENT':
        return 'Assignments';
      case 'EXAM':
        return 'Exams';
      case 'ACADEMIC_ADMIN':
        return 'Administrative';
      case 'OPPORTUNITY':
        return 'Opportunities';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];

    for (final key in _order) {
      final items = groups[key] ?? [];
      if (items.isEmpty) continue; // hide empty categories

      sections.add(_buildSection(context, _labelFor(key), items));
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<AcademicItem> items,
  ) {
    final visible = items.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 140, // Increased height for AI summary
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final it = visible[index];
                return _buildCard(context, it);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, AcademicItem item) {
    final color = topicColor(item.entityType);
    return Container(
      width: 280, // Increased width
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with AI Labels
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.aiLabelTopic ?? item.courseCode ?? 'General',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.aiLabelSource != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.aiLabelSource!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (item.aiSummary != null && item.aiSummary!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                item.aiSummary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ),
          ] else ...[
            const Spacer(),
          ],
          const SizedBox(height: 6),
          // Footer
          Row(
            children: [
              if (item.dueDate != null) ...[
                Icon(Icons.event_available_outlined, size: 14, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  _formatDeadline(item.dueDate!),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (item.location != null) ...[
                Icon(Icons.location_on_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.location!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDeadline(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return 'Overdue';
    if (diff.inDays == 0) return 'Due today';
    if (diff.inDays == 1) return 'Due tomorrow';
    if (diff.inDays < 7) return 'Due in ${diff.inDays} days';
    return DateFormat('MMM d').format(date);
  }
}
