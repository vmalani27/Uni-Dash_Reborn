import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/context_item_tile.dart';

/// Container for displaying information items in a compact, contextual feed.
/// Shows up to 5 items sorted by recency, with inline expand/collapse.
/// Placed below Timeline in the right panel.
class ContextFeedContainer extends StatefulWidget {
  final List<AcademicItem> informationItems;
  final VoidCallback? onItemDismissed;
  final Function(AcademicItem)? onItemTapped;

  const ContextFeedContainer({
    super.key,
    required this.informationItems,
    this.onItemDismissed,
    this.onItemTapped,
  });

  @override
  State<ContextFeedContainer> createState() => _ContextFeedContainerState();
}

class _ContextFeedContainerState extends State<ContextFeedContainer> {
  String? expandedItemId;
  final Set<String> dismissedIds = {};
  String? hoveredItemId;

  /// Filter information items: exclude dismissed, sort by recency, take max 5
  List<AcademicItem> _getFilteredItems() {
    final filtered = widget.informationItems
        .where((item) => item.entityType == 'INFORMATION')
        .where((item) => !item.dismissed && !dismissedIds.contains(item.id.toString()))
        .toList();

    // Sort by last updated time (most recent first)
    // Fallback to due date or epoch if not available
    filtered.sort((a, b) {
      final dateA = a.lastUpdatedAt ?? a.dueDate ?? DateTime(1970);
      final dateB = b.lastUpdatedAt ?? b.dueDate ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    // Return max 5 items
    return filtered.take(5).toList();
  }

  void _handleToggleExpand(String itemId) {
    setState(() {
      expandedItemId = expandedItemId == itemId ? null : itemId;
    });
  }

  void _handleDismiss(String itemId) {
    setState(() {
      dismissedIds.add(itemId);
      expandedItemId = null;
    });
    widget.onItemDismissed?.call();
  }

  void _handleViewFull(AcademicItem item) {
    widget.onItemTapped?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    final items = _getFilteredItems();

    // Hide if no items
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header: "Context"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Context',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.65),
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Items list
        SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                ContextItemTile(
                  item: items[i],
                  isExpanded: expandedItemId == items[i].id.toString(),
                  onExpand: () => _handleToggleExpand(items[i].id.toString()),
                  onDismiss: () => _handleDismiss(items[i].id.toString()),
                  onViewFull: () => _handleViewFull(items[i]),
                  onHoverChanged: (isHovered) {
                    setState(() {
                      hoveredItemId = isHovered ? items[i].id.toString() : null;
                    });
                  },
                ),
                // Gap between items
                if (i < items.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
