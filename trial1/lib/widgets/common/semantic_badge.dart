import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';

class CategoryBadge extends StatelessWidget {
  final String topic;
  final String? label;
  final IconData? icon;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool compact;

  const CategoryBadge({
    super.key,
    required this.topic,
    this.label,
    this.icon,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final meta = academicCategoryMeta(topic);
    final resolvedColor = color ?? meta.color;
    final resolvedLabel = label ?? meta.label;
    final resolvedIcon = icon ?? meta.icon;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: resolvedColor.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolvedIcon, size: compact ? 14 : 15, color: resolvedColor),
          if (!compact) const SizedBox(width: 6),
          if (!compact)
            Text(
              resolvedLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: resolvedColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
        ],
      ),
    );
  }
}

class DeadlineRow extends StatelessWidget {
  final DateTime? deadline;
  final Color color;
  final bool showTime;
  final String? fallbackLabel;
  final String? prefix;

  const DeadlineRow({
    super.key,
    required this.deadline,
    required this.color,
    this.showTime = false,
    this.fallbackLabel,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final label = _resolveLabel();
    if (label.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  String _resolveLabel() {
    final value = deadline;
    if (value == null) return fallbackLabel ?? '';

    final now = DateTime.now();
    if (value.isBefore(now)) {
      return prefix == null ? 'Overdue' : '$prefix Overdue';
    }

    final dateText = showTime
        ? DateFormat.yMMMd().add_jm().format(value)
        : DateFormat.yMMMd().format(value);

    if (prefix == null) return dateText;
    return '$prefix $dateText';
  }
}