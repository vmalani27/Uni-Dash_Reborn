import 'package:flutter/material.dart';
import 'package:trial1/widgets/gmail_notifications_list.dart';

/// This widget is now deprecated. Use GmailNotificationsList for implicit loading and display.
@deprecated
class GmailNotificationsButton extends StatelessWidget {
  const GmailNotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const GmailNotificationsList();
  }
}
