import 'package:flutter/material.dart';
import 'package:trial1/models/academic_event.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/utils/status_formatter.dart';
import 'package:trial1/widgets/common/semantic_badge.dart';

class FocusCard extends StatefulWidget {
  final AcademicItem? item;
  final AcademicEvent? event;
  final VoidCallback? onActionCompleted;
  final VoidCallback? onActionDismissed;
  final Future<void> Function(AcademicItem)? onMarkDoneAction;
  final Future<void> Function(AcademicItem)? onDismissAction;

  const FocusCard({
    super.key,
    this.item,
    this.event,
    this.onActionCompleted,
    this.onActionDismissed,
    this.onMarkDoneAction,
    this.onDismissAction,
  });

  @override
  State<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<FocusCard> {
  bool _isLoading = false;

  Future<void> _markCompleted() async {
    if (widget.item == null) return;
    setState(() => _isLoading = true);
    try {
      if (widget.onMarkDoneAction != null) {
        await widget.onMarkDoneAction!(widget.item!);
      } else {
        await BackendService.markAcademicItemDone(widget.item!.id);
      }
      widget.onActionCompleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _dismiss() async {
    if (widget.item == null) return;
    setState(() => _isLoading = true);
    try {
      if (widget.onDismissAction != null) {
        await widget.onDismissAction!(widget.item!);
      } else {
        await BackendService.dismissAcademicItem(widget.item!.id);
      }
      widget.onActionDismissed?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dismissed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}';
  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.item != null || widget.event != null;
    if (!hasContent) {
      return _buildEmptyState(context);
    }

    final topic = widget.event != null
        ? widget.event!.type.toString().split('.').last
        : (widget.item?.aiLabelTopic ?? widget.item?.entityType ?? 'OTHER');
    final meta = academicCategoryMeta(topic);
    final title = widget.event?.title ?? widget.item?.title ?? '';
    final due = widget.event?.deadline ?? widget.item?.dueDate;
    final status = StatusFormatter.getStatus(due);
    final subtitle = widget.event?.summary ?? widget.item?.aiSummary ?? widget.item?.description;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: meta.color.withValues(alpha: 0.16),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            meta.color.withValues(alpha: 0.08),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: null,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(meta.icon, color: meta.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                        ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                CategoryBadge(
                                  topic: meta.key,
                                  label: meta.label,
                                  icon: meta.icon,
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (due != null)
                                  _StatusPill(
                                    label: 'Due ${StatusFormatter.getTimeDescription(due)}',
                                    accent: status.isUrgent ? meta.color : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                if (widget.item?.courseCode != null)
                                  _StatusPill(
                                    label: widget.item!.courseCode!,
                                    accent: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                if (widget.event?.type != null)
                                  _StatusPill(
                                    label: widget.event!.type.toString().split('.').last,
                                    accent: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (widget.item != null)
                        _buildActionButton(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Done',
                          onTap: _markCompleted,
                        ),
                      if (widget.item != null)
                        _buildActionButton(
                          icon: Icons.remove_circle_outline_rounded,
                          label: 'Dismiss',
                          onTap: _dismiss,
                        ),
                    ],
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      minHeight: 2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: neutral.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.radio_button_checked_outlined, color: neutral, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No focus item',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The dashboard will promote the most urgent item here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: neutral,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusPill({
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
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
