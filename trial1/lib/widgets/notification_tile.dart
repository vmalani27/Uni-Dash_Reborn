import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';

/// Simple tile to display a Gmail notification preview.
class NotificationTile extends StatelessWidget {
  final GmailNotificationPreview notification;

  const NotificationTile({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        notification.subject,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        notification.snippet,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        notification.sender,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
