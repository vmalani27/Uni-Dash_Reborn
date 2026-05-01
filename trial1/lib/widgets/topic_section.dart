import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/widgets/notification_tile.dart';
import '../theme.dart';

/// A collapsible section of notifications grouped by normalized topic.
class TopicSection extends StatelessWidget {
  final String normalizedTopic;
  final List<GmailNotificationPreview> notifications;

  const TopicSection({
    super.key,
    required this.normalizedTopic,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final color = topicColor(normalizedTopic);
    final label = topicLabel(normalizedTopic);
    final icon = topicIcon(normalizedTopic);

    return SliverMainAxisGroup(
      slivers: [
        // Section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${notifications.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Notification tiles
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) =>
                NotificationTile(notification: notifications[index]),
            childCount: notifications.length,
          ),
        ),
      ],
    );
  }
}

