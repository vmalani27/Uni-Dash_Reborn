import 'package:flutter/material.dart';

class GmailSyncStatusIndicator extends StatelessWidget {
  final Color highlightColor;
  final String message;

  const GmailSyncStatusIndicator({
    Key? key,
    required this.highlightColor,
    this.message = 'Syncing emails...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: highlightColor.withOpacity(0.1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
