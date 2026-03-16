import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/notification_cards/priority_dot.dart';
import 'package:trial1/widgets/notification_cards/deadline_display.dart';
import 'package:trial1/utils/time_formatters.dart';

/// Activity card widget.
/// Single responsibility: render an activity notification card.
class ActivityCard extends StatelessWidget {
  final GmailNotificationPreview notification;
  final VoidCallback onTap;

  const ActivityCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: PriorityDot(academicScore: notification.academicScore),
        title: Text(
          notification.subject,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.snippet,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (notification.deadlineIso != null)
                    DeadlineDisplay(deadline: notification.deadlineIso),
                  const Spacer(),
                  Text(
                    notification.internalDate != null
                        ? formatTimeAgo(notification.internalDate!)
                        : '',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
