import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/notification_cards/activity_card.dart';

/// Activity section.
/// Single responsibility: render list of activity cards.
class ActivitySection extends StatelessWidget {
  final List<GmailNotificationPreview> notifications;
  final Function(GmailNotificationPreview) onCardTap;

  const ActivitySection({
    super.key,
    required this.notifications,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Recent',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        if (notifications.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Text(
                'No activity',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...notifications.map(
            (notification) => ActivityCard(
              notification: notification,
              onTap: () => onCardTap(notification),
            ),
          ),
      ],
    );
  }
}
