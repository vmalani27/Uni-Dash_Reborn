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

  const FocusCard({
    super.key,
    this.item,
    this.event,
    this.onActionCompleted,
    this.onActionDismissed,
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
      await BackendService.markAcademicItemDone(widget.item!.id);
      widget.onActionCompleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marked as completed ✓')),
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
      await BackendService.dismissAcademicItem(widget.item!.id);
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

  void _showSnoozeOptions() {
    if (widget.item == null || widget.item!.dueDate == null) return;
    final now = DateTime.now();
    final dueDate = widget.item!.dueDate!;
    final hoursUntilDeadline = dueDate.difference(now).inHours;
    if (hoursUntilDeadline <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot snooze: deadline has passed')),
      );
      return;
    }
    final snoozeOptions = [
      {'label': '1 hour', 'hours': 1},
      {'label': '4 hours', 'hours': 4},
      {'label': '8 hours', 'hours': 8},
      {'label': '1 day', 'hours': 24},
      if (hoursUntilDeadline > 48) {'label': '2 days', 'hours': 48},
      if (hoursUntilDeadline > 72) {'label': '3 days', 'hours': 72},
    ];
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remind me later',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Available until ${_formatDate(dueDate)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),
            ...snoozeOptions.map((opt) => _buildSnoozeOption(
              opt['label'] as String,
              opt['hours'] as int,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSnoozeOption(String label, int hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _snoozeFor(hours),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label),
                Text(
                  'at ${_formatTime(DateTime.now().add(Duration(hours: hours)))}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _snoozeFor(int hours) async {
    if (widget.item == null) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);
    try {
      await BackendService.snoozeAcademicItem(widget.item!.id, hours: hours);
      if (mounted) {
        final snoozeTime = DateTime.now().add(Duration(hours: hours));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Snoozed until ${_formatTime(snoozeTime)}')),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: meta.color.withOpacity(0.4),  // More visible border
          width: 1.5,  // Thicker border
        ),
        boxShadow: [
          // Primary shadow for depth
          BoxShadow(
            color: meta.color.withOpacity(0.18),  // Stronger shadow
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          // Secondary shadow for softness
          BoxShadow(
            color: meta.color.withOpacity(0.08),
            blurRadius: 32,
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
                const SizedBox(height: 4),
                Text(
                  'Due ${StatusFormatter.getTimeDescription(due)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: status.isUrgent
                        ? meta.color
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.64),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 12),
          if (_isLoading)
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(meta.color),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'completed':
                    _markCompleted();
                  case 'dismiss':
                    _dismiss();
                  case 'snooze':
                    _showSnoozeOptions();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'completed',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('Completed'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'dismiss',
                  child: Row(
                    children: [
                      Icon(Icons.clear, size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Dismiss'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'snooze',
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Snooze...'),
                    ],
                  ),
                ),
              ],
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.56),
                  ),
                ),
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
