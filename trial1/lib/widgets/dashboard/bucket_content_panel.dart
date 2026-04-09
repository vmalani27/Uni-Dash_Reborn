import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/academic_item_card.dart';

/// Displays the content (items) for the selected bucket category.
/// Appears below the bucket tabs with smooth fade+expand animation.
class BucketContentPanel extends StatelessWidget {
  final String? selectedBucket;
  final Map<String, List<AcademicItem>> groupedItems;
  final VoidCallback? onClose;

  const BucketContentPanel({
    super.key,
    required this.selectedBucket,
    required this.groupedItems,
    this.onClose,
  });

  /// Maps bucket label to data key
  String _mapBucketToKey(String label) {
    switch (label) {
      case 'Assignments':
        return 'ASSIGNMENT';
      case 'Exams':
        return 'EXAM';
      case 'Opportunities':
        return 'OPPORTUNITY';
      case 'Announcements':
        return 'ACADEMIC_ADMIN';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (selectedBucket == null) {
      return const SizedBox.shrink();
    }

    final key = _mapBucketToKey(selectedBucket!);
    final items = groupedItems[key] ?? [];
    final meta = academicCategoryMeta(key);

    /// Get category-specific empty state message
    String _getEmptyStateMessage() {
      switch (selectedBucket) {
        case 'Assignments':
          return 'No active assignments';
        case 'Exams':
          return 'No upcoming exams';
        case 'Opportunities':
          return 'No available opportunities';
        case 'Announcements':
          return 'No announcements';
        default:
          return 'Nothing to show';
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.05),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(selectedBucket),
        width: double.infinity,
        decoration: BoxDecoration(
          color: meta.tint(0.02),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(11),
            bottomRight: Radius.circular(11),
          ),
          border: Border(
            left: BorderSide(
              color: meta.color.withOpacity(
                Theme.of(context).brightness == Brightness.light ? 0.25 : 0.12,
              ),
              width: Theme.of(context).brightness == Brightness.light ? 1.5 : 1,
            ),
            right: BorderSide(
              color: meta.color.withOpacity(
                Theme.of(context).brightness == Brightness.light ? 0.25 : 0.12,
              ),
              width: Theme.of(context).brightness == Brightness.light ? 1.5 : 1,
            ),
            bottom: BorderSide(
              color: meta.color.withOpacity(
                Theme.of(context).brightness == Brightness.light ? 0.25 : 0.12,
              ),
              width: Theme.of(context).brightness == Brightness.light ? 1.5 : 1,
            ),
          ),
        ),
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                child: Center(
                  child: Text(
                    _getEmptyStateMessage(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items
                      .map((item) => AcademicItemCard(
                        item: item,
                        onTap: () {},
                        previewOnTap: true,
                        hideLabel: true,
                      ))
                      .toList(),
                ),
              ),
      ),
    );
  }
}
