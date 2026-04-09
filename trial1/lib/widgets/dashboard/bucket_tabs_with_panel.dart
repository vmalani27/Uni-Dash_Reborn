import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/dashboard/bucket_content_panel.dart';
import 'package:trial1/theme.dart';

/// Interactive bucket tabs with connected content panel below.
/// When a bucket card is tapped, it becomes active and shows a panel with its items below.
/// Tapping an active bucket again deselects it (collapses the panel).
/// This replaces the old behavior of navigating to a separate list page.
class BucketTabsWithPanel extends StatefulWidget {
  final Map<String, int> counts;
  final Map<String, List<AcademicItem>> groupedItems;

  const BucketTabsWithPanel({
    super.key,
    required this.counts,
    required this.groupedItems,
  });

  @override
  State<BucketTabsWithPanel> createState() => _BucketTabsWithPanelState();
}

class _BucketTabsWithPanelState extends State<BucketTabsWithPanel> {
  String? selectedBucket;

  void _handleBucketSelect(String label) {
    setState(() {
      // Toggle: if already selected, deselect. Otherwise select.
      selectedBucket = selectedBucket == label ? null : label;
    });
  }

  void _handlePanelClose() {
    setState(() {
      selectedBucket = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs
        _BucketTabsRow(
          counts: widget.counts,
          selectedBucket: selectedBucket,
          onSelect: _handleBucketSelect,
        ),
        // Connected content panel (animated)
        BucketContentPanel(
          selectedBucket: selectedBucket,
          groupedItems: widget.groupedItems,
          onClose: _handlePanelClose,
        ),
      ],
    );
  }
}

/// Tab row with visual active state.
/// Tab row with visual selected state indicators.
class _BucketTabsRow extends StatelessWidget {
  final Map<String, int> counts;
  final String? selectedBucket;
  final void Function(String) onSelect;

  const _BucketTabsRow({
    required this.counts,
    required this.selectedBucket,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      _CategoryEntry('Assignments', 'ASSIGNMENT'),
      _CategoryEntry('Exams', 'EXAM'),
      _CategoryEntry('Opportunities', 'OPPORTUNITY'),
      _CategoryEntry('Announcements', 'ACADEMIC_ADMIN'),
    ];

    final tabWidgets = entries.map((entry) {
      final meta = academicCategoryMeta(entry.topicKey);
      final value = counts[entry.label] ?? counts[entry.topicKey] ?? 0;
      final isSelected = selectedBucket == entry.label;

      return Expanded(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onSelect(entry.label),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface.withOpacity(0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.1)
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  // Row 1: Icon, name, and state indicator
                  Row(
                    children: [
                      Icon(
                        meta.icon,
                        size: 15,
                        color: isSelected
                            ? meta.color
                            : meta.color.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.label,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 12,
                            color: isSelected
                                ? null
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // State indicator
                      Icon(
                        isSelected ? Icons.expand_less : Icons.chevron_right,
                        size: 14,
                        color: meta.color.withOpacity(isSelected ? 0.7 : 0.4),
                      ),
                    ],
                  ),
                  // Row 2: Count as secondary text
                  Text(
                    value == 1 ? '1 item' : '$value items',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(
                        isSelected ? 0.7 : 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();

    final tabsWithGaps = <Widget>[];
    for (int i = 0; i < tabWidgets.length; i++) {
      tabsWithGaps.add(tabWidgets[i]);
      if (i < tabWidgets.length - 1) {
        tabsWithGaps.add(const SizedBox(width: 12));
      }
    }

    return Row(
      children: tabsWithGaps,
    );
  }
}

class _CategoryEntry {
  final String label;
  final String topicKey;

  const _CategoryEntry(this.label, this.topicKey);
}
