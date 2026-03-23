import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/theme.dart';

class ExpandableTile extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onTap;

  const ExpandableTile({super.key, required this.event, this.onTap});

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
    String timeLabel = '';
    if (timeIso != null) {
      try {
        final dt = DateTime.parse(timeIso).toLocal();
        timeLabel = DateFormat.yMMMd().add_jm().format(dt);
      } catch (_) {
        timeLabel = timeIso;
      }
    }

    final desc = widget.event['description'] as String? ?? '';
    final instructor = widget.event['instructor'] as String?;
    final type = widget.event['type'] as String? ?? 'INFORMATION';
    final color = topicColor(type);

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
          if (widget.onTap != null) widget.onTap!();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: showExpanded ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    if (showExpanded &&
                        (desc.isNotEmpty || instructor != null)) ...[
                      const SizedBox(height: 8),
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (instructor != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Instructor: $instructor',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
