/// Pure time formatting utilities.
/// No widget dependencies. No state. Just calculations.
library;

String formatDeadline(DateTime deadline) {
  final now = DateTime.now();
  final difference = deadline.difference(now);

  if (difference.isNegative) {
    return 'Overdue';
  } else if (difference.inDays > 0) {
    return '${difference.inDays}d left';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h left';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m left';
  } else {
    return 'Due now';
  }
}

String formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'now';
  }
}

/// Detailed deadline display for cards
/// Returns (timeText, timeColor)
(String, dynamic) getDeadlineDisplay(DateTime? deadline) {
  if (deadline == null) return ('', null);

  final now = DateTime.now();
  final difference = deadline.difference(now);

  String timeText;
  dynamic timeColor;

  if (difference.isNegative) {
    timeText = 'OVERDUE';
    timeColor = 'red';
  } else if (difference.inDays > 0) {
    timeText = '${difference.inDays}d left';
    timeColor = 'orange';
  } else if (difference.inHours > 0) {
    timeText = '${difference.inHours}h left';
    timeColor = 'yellow';
  } else if (difference.inMinutes > 0) {
    timeText = '${difference.inMinutes}m left';
    timeColor = 'red';
  } else {
    timeText = 'DUE NOW';
    timeColor = 'red';
  }

  return (timeText, timeColor);
}
