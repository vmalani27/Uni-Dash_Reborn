import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/notification_cards/action_required_card.dart';

/// Action required section.
/// Single responsibility: render list of high-priority action cards.
class ActionRequiredSection extends StatelessWidget {
  final List<GmailNotificationPreview> notifications;
  final Function(GmailNotificationPreview) onCardTap;

  const ActionRequiredSection({
    super.key,
    required this.notifications,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Action Required',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
            ),
          ),
        ),
        ...notifications.map(
          (notification) => ActionRequiredCard(
            notification: notification,
            onTap: () => onCardTap(notification),
          ),
        ),
      ],
    );
  }
}
