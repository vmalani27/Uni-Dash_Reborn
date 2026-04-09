import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/utils/status_formatter.dart';
import 'package:trial1/widgets/common/semantic_badge.dart';

/// Individual context feed item tile with inline expand/collapse.
/// Displays a compact row when collapsed, full details when expanded.
class ContextItemTile extends StatelessWidget {
  final AcademicItem item;
  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onDismiss;
  final VoidCallback? onViewFull;
  final ValueChanged<bool>? onHoverChanged;

  const ContextItemTile({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onExpand,
    required this.onDismiss,
    this.onViewFull,
    this.onHoverChanged,
  });

  String _getTimeDescription(DateTime? date) {
    if (date == null) return '';
    return StatusFormatter.getTimeDescription(date);
  }

  @override
  Widget build(BuildContext context) {
    final meta = academicCategoryMeta(item.entityType ?? 'INFORMATION');

    return MouseRegion(
      onEnter: (_) => onHoverChanged?.call(true),
      onExit: (_) => onHoverChanged?.call(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onExpand,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isExpanded
                  ? Theme.of(context).colorScheme.surface.withOpacity(
                      Theme.of(context).brightness == Brightness.light ? 0.05 : 0.08,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            child: isExpanded
                ? _buildExpandedContent(context, meta)
                : _buildCollapsedRow(context, meta),
          ),
        ),
      ),
    );
  }

  /// Compact single-line row: [dot] [title] [time] [hover: close icon]
  Widget _buildCollapsedRow(BuildContext context, AcademicCategoryMeta meta) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Dot indicator
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF64748B).withOpacity(0.5),  // Slate color
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),

        // Title (flexed)
        Expanded(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Time (right-aligned)
        Text(
          _getTimeDescription(item.dueDate),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// Expanded view: collapsed row + description + badge + action button
  Widget _buildExpandedContent(BuildContext context, AcademicCategoryMeta meta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Collapsed row content
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF64748B).withOpacity(0.5),  // Slate color
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getTimeDescription(item.dueDate),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Description (if available)
        if ((item.description?.isNotEmpty ?? false) ||
            (item.aiSummary?.isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.only(left: 14),  // Align with text above dot
            child: Text(
              item.aiSummary ?? item.description ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Badge + action row
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(
            children: [
              CategoryBadge(
                topic: item.entityType ?? 'INFORMATION',
                label: meta.label,
                icon: meta.icon,
                compact: true,
              ),
              const Spacer(),
              TextButton(
                onPressed: onViewFull ?? () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 24),
                ),
                child: Text(
                  'View Full',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
