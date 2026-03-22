import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/theme.dart';

class AcademicItemCard extends StatelessWidget {
  final AcademicItem item;
  final VoidCallback onTap;
  // When true, tapping opens preview dialog instead of immediately calling onTap
  final bool previewOnTap;

  const AcademicItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.previewOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: () {
          if (previewOnTap) {
            _showPreview(context);
          } else {
            onTap();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Collapsed chips row: show topic and source for quick scanning
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (item.aiLabelTopic != null)
                    _chip(context, item.aiLabelTopic!),
                  if (item.aiLabelSource != null)
                    _chip(context, item.aiLabelSource!),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Theme.of(context).cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            // due date + chips
                            if (item.dueDate != null) ...[
                              Text(
                                _shortDateWithContext(item.dueDate!),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.7),
                                    ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (item.aiLabelTopic != null)
                                  _chip(context, item.aiLabelTopic!),
                                if (item.aiLabelSource != null)
                                  _chip(context, item.aiLabelSource!),
                                if (item.courseCode != null)
                                  _chip(context, item.courseCode!),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Summary / description
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Summary',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          // Allow summary to expand inside the dialog. Wrap with
                          // a scrollable in case the text is long.
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 360),
                            child: SingleChildScrollView(
                              child: Text(
                                (item.aiSummary ?? item.description),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Follow-ups / actions
                  if (item.followUps != null && item.followUps!.isNotEmpty) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Follow-ups',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...item.followUps!.map(
                              (f) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        f.message,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                    if (f.triggerAt != null) ...[
                                      const SizedBox(width: 12),
                                      Text(
                                        _shortDate(f.triggerAt!),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // delegate to onTap to view full email / details
                          onTap();
                        },
                        child: const Text('View Full Email'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _shortDate(DateTime d) {
    try {
      return DateFormat('MMM d').format(d);
    } catch (_) {
      return d.toIso8601String();
    }
  }

  String _shortDateWithContext(DateTime d) {
    try {
      final now = DateTime.now();
      final diff = d.difference(now).inDays;
      if (diff == 0 && d.day == now.day) return 'Today';
      if (diff == 1) return 'Tomorrow';
      return DateFormat('MMM d').format(d);
    } catch (_) {
      return d.toIso8601String();
    }
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    Color entityColor;
    IconData entityIcon;
    switch (item.entityType.toLowerCase()) {
      case 'assignment':
        entityColor = kTopicAssignment;
        entityIcon = Icons.assignment_outlined;
        break;
      case 'exam':
        entityColor = kTopicExam;
        entityIcon = Icons.quiz_outlined;
        break;
      case 'opportunity':
        entityColor = kTopicOpportunity;
        entityIcon = Icons.rocket_launch_outlined;
        break;
      case 'announcement':
        entityColor = kTopicInformation;
        entityIcon = Icons.campaign_outlined;
        break;
      case 'event':
        entityColor = kTopicAcademic;
        entityIcon = Icons.event_outlined;
        break;
      default:
        entityColor = kTopicOther;
        entityIcon = Icons.category_outlined;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: entityColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: entityColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(entityIcon, size: 14, color: entityColor),
              const SizedBox(width: 6),
              Text(
                item.entityType.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: entityColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (item.courseCode != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.courseCode!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (item.dueDate != null) ...[
                Icon(
                  Icons.event_available_outlined,
                  size: 16,
                  color: _getDueDateColor(item.dueDate!, context),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(item.dueDate!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getDueDateColor(item.dueDate!, context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else if (item.location != null) ...[
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.location!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Action buttons (compact)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.add_alert_outlined,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onPressed: () {},
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0 && date.day == now.day) {
      return 'Today';
    } else if (difference == 1 ||
        (difference == 0 && date.day == now.day + 1)) {
      return 'Tomorrow';
    } else if (difference < 0 && difference > -7) {
      return '${-difference}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Color _getDueDateColor(DateTime date, BuildContext context) {
    if (item.completed) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    }

    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference < 0) {
      return Theme.of(context).colorScheme.error; // overdue
    }
    if (difference <= 2) {
      return kUrgencyCritical;
    }
    if (difference <= 7) {
      return kUrgencyHigh;
    }
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
  }
}
