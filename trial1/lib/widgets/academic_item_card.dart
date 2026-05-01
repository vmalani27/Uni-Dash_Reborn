import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/academic_item_actions.dart';
import 'package:trial1/theme.dart';

enum _SecondaryItemAction { calendar, dismiss }

class AcademicItemCard extends StatelessWidget {
  final AcademicItem item;
  final VoidCallback onTap;
  final Future<void> Function()? onActionCompleted;
  final Future<void> Function(AcademicItem)? onMarkDoneAction;
  final Future<void> Function(AcademicItem)? onAddToCalendarAction;
  final Future<void> Function(AcademicItem)? onDismissAction;
  final bool previewOnTap;
  final bool hideLabel;

  const AcademicItemCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onActionCompleted,
    this.onMarkDoneAction,
    this.onAddToCalendarAction,
    this.onDismissAction,
    this.previewOnTap = true,
    this.hideLabel = false,
  });

  Future<void> _handleMarkDone() async {
    if (onMarkDoneAction != null) {
      await onMarkDoneAction!(item);
      return;
    }
    await BackendService.markAcademicItemDone(item.id);
  }

  Future<void> _handleAddToCalendar() async {
    if (onAddToCalendarAction != null) {
      await onAddToCalendarAction!(item);
      return;
    }
    await BackendService.addAcademicItemToCalendar(item.id);
  }

  Future<void> _handleDismiss() async {
    if (onDismissAction != null) {
      await onDismissAction!(item);
      return;
    }
    await BackendService.dismissAcademicItem(item.id);
  }

  String _deadlineLabel(DateTime? date) {
    if (date == null) return 'No deadline';
    return DateFormat.yMMMd().add_jm().format(date);
  }

  @override
  Widget build(BuildContext context) {
    final meta = academicCategoryMeta(item.entityType);
    final accent = meta.color;
    final summary = (item.summary?.trim().isNotEmpty ?? false)
        ? item.summary!
        : (item.aiSummary?.trim().isNotEmpty ?? false)
            ? item.aiSummary!
        : item.description;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (previewOnTap) {
              _showPreview(context);
            } else {
              onTap();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withValues(alpha: 0.16)),
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.05,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(meta.icon, color: accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                PopupMenuButton<_SecondaryItemAction>(
                                  tooltip: 'More actions',
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  onSelected: (action) async {
                                    switch (action) {
                                      case _SecondaryItemAction.calendar:
                                        await _handleAddToCalendar();
                                        break;
                                      case _SecondaryItemAction.dismiss:
                                        await _handleDismiss();
                                        break;
                                    }
                                    await onActionCompleted?.call();
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<_SecondaryItemAction>(
                                      value: _SecondaryItemAction.calendar,
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.calendar_today_outlined, size: 18),
                                        title: Text('Add to calendar'),
                                      ),
                                    ),
                                    PopupMenuItem<_SecondaryItemAction>(
                                      value: _SecondaryItemAction.dismiss,
                                      child: ListTile(
                                        dense: true,
                                        leading: Icon(Icons.delete_outline, size: 18),
                                        title: Text('Dismiss'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaPill(label: meta.label, accent: accent),
                                if (item.courseCode != null)
                                  _MetaPill(label: item.courseCode!, accent: Theme.of(context).colorScheme.onSurfaceVariant),
                                if (item.aiLabelSource != null)
                                  _MetaPill(label: item.aiLabelSource!, accent: Theme.of(context).colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!hideLabel) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
                  ],
                  if (!hideLabel) ...[
                    const SizedBox(height: 14),
                    Text(
                      topicLabel(item.aiLabelTopic ?? item.entityType).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.12,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                    ),
                  ],
                  if (summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    _deadlineLabel(item.dueDate ?? item.eventDate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: () async {
                          try {
                            await _handleMarkDone();
                            await onActionCompleted?.call();
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.check_rounded),
                        tooltip: 'Mark done',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        Future<void> runAction(
          Future<void> Function() action,
          String successMessage,
        ) async {
          await action();
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage)),
            );
          }
          await onActionCompleted?.call();
        }

        final meta = academicCategoryMeta(item.entityType);
        final summary = (item.summary?.trim().isNotEmpty ?? false)
            ? item.summary!
            : (item.aiSummary?.trim().isNotEmpty ?? false)
                ? item.aiSummary!
            : item.description;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaPill(label: meta.label, accent: meta.color),
                                if (item.courseCode != null)
                                  _MetaPill(label: item.courseCode!, accent: Theme.of(context).colorScheme.onSurfaceVariant),
                                if (item.aiLabelSource != null)
                                  _MetaPill(label: item.aiLabelSource!, accent: Theme.of(context).colorScheme.onSurfaceVariant),
                                if (item.dueDate != null)
                                  _MetaPill(label: _deadlineLabel(item.dueDate), accent: Theme.of(context).colorScheme.onSurfaceVariant),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: 'Summary',
                    child: Text(
                      summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.55,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Full email',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.55,
                              fontSize: 12.5,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (item.followUps != null && item.followUps!.isNotEmpty) ...[
                    _SectionCard(
                      title: 'Follow-ups',
                      child: Column(
                        children: [
                          for (final followUp in item.followUps!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.arrow_right_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      followUp.message,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  if (followUp.triggerAt != null) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      DateFormat.yMMMd().format(followUp.triggerAt!),
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SectionCard(
                    title: 'Actions',
                    child: AcademicItemActionBar(
                      onMarkDone: () => runAction(_handleMarkDone, 'Marked as done'),
                      onAddToCalendar: () => runAction(_handleAddToCalendar, 'Added to calendar'),
                      onDismiss: () => runAction(_handleDismiss, 'Dismissed'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _MetaPill({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: accent,
            ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
