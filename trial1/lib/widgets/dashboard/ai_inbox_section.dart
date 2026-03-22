import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/widgets/notification_tile.dart';

class AiInboxSection extends StatelessWidget {
  final List<GmailNotificationPreview> messages;

  const AiInboxSection({
    super.key,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('AI Inbox is empty. Processed emails will appear here.'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return NotificationTile(notification: messages[index]);
      },
    );
  }
}
