import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';

class TabsSection extends StatefulWidget {
  final Map<String, List<AcademicItem>> groups;

  const TabsSection({super.key, required this.groups});

  @override
  State<TabsSection> createState() => _TabsSectionState();
}

class _TabsSectionState extends State<TabsSection>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  List<String> get _tabs => widget.groups.keys.toList();

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    final currentItems = widget.groups[tabs[_selectedIndex]] ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill segmented control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tabs.length, (i) {
                final selected = i == _selectedIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedIndex = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        child: Text(
                          tabs[i],
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 12),

          // Horizontal scroll cards for selected category
          if (currentItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Text(
                'No items in this category',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: currentItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = currentItems[index];
                  final color = topicColor(item.entityType);
                  return Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: color.withOpacity(0.15)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.courseCode ?? 'General',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (item.dueDate != null)
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDeadline(item.dueDate!),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
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
