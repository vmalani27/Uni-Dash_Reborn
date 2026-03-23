import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/theme.dart';
import 'package:intl/intl.dart';

class CategoryScrollSection extends StatelessWidget {
  final String title;
  final List<AcademicItem> items;
  final Function(AcademicItem) onItemTap;

  const CategoryScrollSection({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _HorizontalCategoryCard(
                item: item,
                onTap: () => onItemTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HorizontalCategoryCard extends StatelessWidget {
  final AcademicItem item;
  final VoidCallback onTap;

  const _HorizontalCategoryCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = topicColor(item.entityType);

    return Container(
      width: 260,
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.2), width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(topicIcon(item.entityType), size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.courseCode ?? 'General',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                if (item.dueDate != null)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDeadline(item.dueDate!),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
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
