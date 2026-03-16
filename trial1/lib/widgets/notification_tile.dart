import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/email_detail_dialog.dart';
import '../theme.dart';

/// A single notification tile with topic chip, urgency border, and deadline badge.
class NotificationTile extends StatelessWidget {
  final GmailNotificationPreview notification;

  const NotificationTile({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final Color topic = topicColor(notification.normalizedTopic);
    final bool hasDeadline = notification.deadlineIso != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 400),
        openBuilder: (context, _) =>
            _EmailDetailLoader(gmailId: notification.gmailId),
        closedElevation: 0,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        closedColor: Theme.of(context).cardColor,
        onClosed: (_) => HapticFeedback.lightImpact(),
        closedBuilder: (context, openContainer) {
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              openContainer();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(color: topic.withOpacity(0.7), width: 3),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Topic chip + time
                  Row(
                    children: [
                      _TopicChip(topic: notification.normalizedTopic),
                      if (hasDeadline) ...[
                        const SizedBox(width: 8),
                        _DeadlineBadge(deadline: notification.deadlineIso!),
                      ],
                      const Spacer(),
                      Text(
                        notification.internalDate != null
                            ? _formatTimeAgo(notification.internalDate!)
                            : '',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: Sender
                  Text(
                    notification.sender,
                    style: Theme.of(context).textTheme.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Row 3: Subject
                  Text(
                    notification.subject,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Row 4: Snippet
                  Text(
                    notification.snippet,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dateTime.day}/${dateTime.month}';
  }
}

// ─── Topic Chip ─────────────────────────────────────────────
class _TopicChip extends StatelessWidget {
  final String topic;
  const _TopicChip({required this.topic});

  @override
  Widget build(BuildContext context) {
    final color = topicColor(topic);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(topicIcon(topic), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            topicLabel(topic),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Deadline Badge ─────────────────────────────────────────
class _DeadlineBadge extends StatelessWidget {
  final DateTime deadline;
  const _DeadlineBadge({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    final isOverdue = diff.isNegative;
    final color = isOverdue
        ? kUrgencyCritical
        : (diff.inDays <= 2 ? kUrgencyHigh : kUrgencyMedium);

    String label;
    if (isOverdue) {
      label = 'Overdue';
    } else if (diff.inHours < 24) {
      label = 'Due today';
    } else if (diff.inDays == 1) {
      label = 'Due tomorrow';
    } else if (diff.inDays <= 7) {
      label = 'Due in ${diff.inDays}d';
    } else {
      label = 'Due ${deadline.day}/${deadline.month}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailDetailLoader extends StatefulWidget {
  final String gmailId;

  const _EmailDetailLoader({required this.gmailId});

  @override
  State<_EmailDetailLoader> createState() => _EmailDetailLoaderState();
}

class _EmailDetailLoaderState extends State<_EmailDetailLoader> {
  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    // Cache the future here so it only fires ONCE when the widget is created
    _detailFuture = BackendService.fetchGmailMessageDetail(widget.gmailId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            appBar: AppBar(leading: const CloseButton()),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        final detail = GmailMessageDetail.fromJson(snapshot.data!);
        return EmailDetailScreen(
          initialMessage: detail,
          gmailId: widget.gmailId,
        );
      },
    );
  }
}
