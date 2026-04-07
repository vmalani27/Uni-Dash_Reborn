import 'package:flutter/material.dart';
import 'package:trial1/models/academic_event.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/common/semantic_badge.dart';

class FocusCard extends StatelessWidget {
  final AcademicItem? item;
  final AcademicEvent? event;

  const FocusCard({
    super.key,
    this.item,
    this.event,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = item != null || event != null;
    if (!hasContent) {
      return _buildEmptyState(context);
    }

    final topic = event != null
        ? event!.type.toString().split('.').last
        : (item?.aiLabelTopic ?? item?.entityType ?? 'OTHER');
    final meta = academicCategoryMeta(topic);
    final title = event?.title ?? item?.title ?? '';
    final due = event?.deadline ?? item?.dueDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(
          (255 * 0.96).toInt(),
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: meta.color.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: meta.color.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: meta.color.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CategoryBadge(
            topic: meta.key,
            label: meta.label,
            icon: meta.icon,
            compact: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                DeadlineRow(
                  deadline: due,
                  color: meta.color,
                  showTime: false,
                  fallbackLabel: item?.location,
                  prefix: due != null ? 'Due' : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Focus',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.56),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final neutral = Theme.of(context).colorScheme.onSurface.withOpacity(0.62);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(
          (255 * 0.96).toInt(),
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: neutral.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.radio_button_checked_outlined, 
              color: neutral, 
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No focus item',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Focus',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.56),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
