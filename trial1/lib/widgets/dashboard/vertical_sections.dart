import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/common/semantic_badge.dart';

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
          Row(
            children: [
              CategoryBadge(
                topic: academicCategoryMeta(items.first.entityType).key,
                label: title,
                icon: academicCategoryMeta(items.first.entityType).icon,
              ),
              const SizedBox(width: 10),
              Text(
                '${items.length} items',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.62),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 152,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate card width based on available width
                // Account for separator width (10px) and padding
                const separatorWidth = 10;
                final availableWidth = constraints.maxWidth;
                
                // Determine cards per row based on screen size
                int cardsPerRow;
                final parentWidth = MediaQuery.of(context).size.width;
                if (parentWidth < 600) {
                  // Mobile: 1 card visible
                  cardsPerRow = 1;
                } else if (parentWidth < 900) {
                  // Tablet: 2 cards visible
                  cardsPerRow = 2;
                } else {
                  // Desktop: 3-4 cards visible
                  cardsPerRow = 3;
                }
                
                // Calculate card width
                final totalSeparatorWidth = separatorWidth * (cardsPerRow - 1);
                final cardWidth = 
                    ((availableWidth - totalSeparatorWidth) / cardsPerRow).floorToDouble();

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final it = visible[index];
                    return SizedBox(
                      width: cardWidth,
                      child: _buildCard(context, it),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, AcademicItem item) {
    final meta = academicCategoryMeta(item.entityType);
    final accent = meta.color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: meta.tint(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(
                topic: item.aiLabelTopic ?? item.entityType,
                label: topicLabel(item.aiLabelTopic ?? item.entityType),
                icon: topicIcon(item.aiLabelTopic ?? item.entityType),
                compact: true,
              ),
              const Spacer(),
              if (item.aiLabelSource != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
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
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (item.aiSummary != null && item.aiSummary!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                item.aiSummary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ),
          ] else ...[
            const Spacer(),
          ],
          const SizedBox(height: 4),
          // Footer
          Row(
            children: [
              if (item.dueDate != null) ...[
                Icon(Icons.event_available_outlined, size: 12, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    _formatDeadline(item.dueDate!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (item.location != null) ...[
                Icon(Icons.location_on_outlined, size: 12, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    item.location!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
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
    return date.toIso8601String();
  }
}
