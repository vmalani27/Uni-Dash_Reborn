import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/common/semantic_badge.dart';

class ExpandableTile extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onTap;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onAddToCalendar;
  final VoidCallback? onDismiss;

  const ExpandableTile({
    super.key,
    required this.event,
    this.onTap,
    this.onMarkCompleted,
    this.onAddToCalendar,
    this.onDismiss,
  });

  @override
  State<ExpandableTile> createState() => _ExpandableTileState();
}

class _ExpandableTileState extends State<ExpandableTile> {
  bool isHovered = false;
  bool isExpandedMobile = false;

  void _toggleMobile() {
    setState(() => isExpandedMobile = !isExpandedMobile);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.event['title'] as String? ?? '';
    final timeIso = widget.event['time'] as String?;
    final desc = widget.event['description'] as String? ?? '';
    final instructor = widget.event['instructor'] as String?;
    final type = widget.event['type'] as String? ?? 'INFORMATION';
    final meta = academicCategoryMeta(type);

    DateTime? timeValue;
    String timeLabel = '';
    if (timeIso != null) {
      try {
        timeValue = DateTime.parse(timeIso).toLocal();
        timeLabel = DateFormat.yMMMd().add_jm().format(timeValue);
      } catch (_) {
        timeLabel = timeIso;
      }
    }

    final showExpanded =
        kIsWeb ||
            Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.linux ||
            Theme.of(context).platform == TargetPlatform.macOS
        ? isHovered
        : isExpandedMobile;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (!kIsWeb) {
            _toggleMobile();
          }
          widget.onTap?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: meta.tint(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: meta.color.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
                      color: meta.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(meta.icon, color: meta.color, size: 22),
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
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
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
                        Row(
                          children: [
                            if (timeValue != null)
                              DeadlineRow(
                                deadline: timeValue,
                                color: meta.color,
                                showTime: true,
                                prefix: null,
                              )
                            else if (timeLabel.isNotEmpty)
                              Text(
                                timeLabel,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.66),
                                      fontWeight: FontWeight.w600,
                                    ),
                              )
                            else
                              Text(
                                'No date provided',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.58),
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showExpanded && desc.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  desc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.82),
                        height: 1.45,
                      ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (showExpanded && instructor != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.62),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        instructor,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.72),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (widget.onMarkCompleted != null ||
                  widget.onAddToCalendar != null ||
                  widget.onDismiss != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onMarkCompleted != null)
                      _TimelineActionChip(
                        label: 'Done',
                        icon: Icons.task_alt_outlined,
                        color: meta.color,
                        onTap: widget.onMarkCompleted!,
                      ),
                    if (widget.onAddToCalendar != null)
                      _TimelineActionChip(
                        label: 'Calendar',
                        icon: Icons.calendar_month_outlined,
                        color: meta.color,
                        onTap: widget.onAddToCalendar!,
                      ),
                    if (widget.onDismiss != null)
                      _TimelineActionChip(
                        label: 'Dismiss',
                        icon: Icons.hide_source_outlined,
                        color: meta.color,
                        onTap: widget.onDismiss!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TimelineActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        foregroundColor: color,
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 14, color: color),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

