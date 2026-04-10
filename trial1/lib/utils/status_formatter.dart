import 'package:flutter/material.dart';
import 'package:trial1/utils/priority_scorer.dart';

/// Urgency levels for visual card hierarchy
enum UrgencyLevel { urgent, high, normal }

/// Status display for academic items
/// Provides consistent, clear status labels across the app
class ItemStatus {
  final String label;
  final String description;
  final bool isUrgent;

  ItemStatus({
    required this.label,
    required this.description,
    required this.isUrgent,
  });
}

/// Unified status system for academic items
class StatusFormatter {
  /// Get status for an item based on deadline and tier
  static ItemStatus getStatus(DateTime? dueDate) {
    final tier = PriorityScorer.getTimeTier(dueDate);

    switch (tier) {
      case TimeTier.overdue:
        return ItemStatus(
          label: 'Missed',
          description: 'This deadline has passed',
          isUrgent: true,
        );

      case TimeTier.today:
        return ItemStatus(
          label: 'Due today',
          description: 'Complete today to stay on track',
          isUrgent: true,
        );

      case TimeTier.tomorrow:
        return ItemStatus(
          label: 'Tomorrow',
          description: 'Due tomorrow',
          isUrgent: true,
        );

      case TimeTier.thisWeek:
        return ItemStatus(
          label: 'This week',
          description: 'Due within 7 days',
          isUrgent: false,
        );

      case TimeTier.later:
        return ItemStatus(
          label: 'Upcoming',
          description: 'Plenty of time available',
          isUrgent: false,
        );
    }
  }

  /// Get action hint based on status and category
  static String getActionHint(String? category, DateTime? dueDate) {
    final tier = PriorityScorer.getTimeTier(dueDate);
    final categoryUpper = category?.toUpperCase() ?? 'ASSIGNMENT';

    switch (tier) {
      case TimeTier.overdue:
        if (categoryUpper == 'ASSIGNMENT') {
          return 'Check if late submissions are accepted';
        } else if (categoryUpper == 'EXAM') {
          return 'Contact instructor for conflict resolution';
        } else if (categoryUpper == 'OPPORTUNITY') {
          return 'You may still apply if late applications are allowed';
        }
        return 'Take action if possible';

      case TimeTier.today:
        if (categoryUpper == 'ASSIGNMENT') {
          return 'Start now to meet today\'s deadline';
        } else if (categoryUpper == 'EXAM') {
          return 'Review today\'s exam schedule';
        }
        return 'Complete today to stay on track';

      case TimeTier.tomorrow:
        return 'Prepare tonight for tomorrow\'s deadline';

      case TimeTier.thisWeek:
        return 'Block time this week to complete';

      case TimeTier.later:
        return 'Plan and schedule your approach';
    }
  }

  /// Get relative time description
  static String getTimeDescription(DateTime? dueDate) {
    if (dueDate == null) return 'No deadline set';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final daysDiff = dueDay.difference(today).inDays;

    if (daysDiff < 0) {
      final daysOverdue = -daysDiff;
      return 'Overdue by $daysOverdue ${daysOverdue == 1 ? "day" : "days"}';
    } else if (daysDiff == 0) {
      final hour = dueDate.hour.toString().padLeft(2, '0');
      final minute = dueDate.minute.toString().padLeft(2, '0');
      return 'Due today at $hour:$minute';
    } else if (daysDiff == 1) {
      final hour = dueDate.hour.toString().padLeft(2, '0');
      final minute = dueDate.minute.toString().padLeft(2, '0');
      return 'Tomorrow at $hour:$minute';
    } else if (daysDiff <= 7) {
      return '$daysDiff days from now';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dueDate.month - 1]} ${dueDate.day}';
    }
  }

  /// Determine urgency level based on deadline
  /// Used for card visual hierarchy (colors, borders, etc)
  static UrgencyLevel getUrgencyLevel(DateTime? dueDate) {
    if (dueDate == null) return UrgencyLevel.normal;
    
    final now = DateTime.now();
    final hoursUntil = dueDate.difference(now).inHours;
    
    // Urgent: Overdue or < 24 hours
    if (hoursUntil < 0 || hoursUntil <= 24) {
      return UrgencyLevel.urgent;
    }
    
    // High: 24-48 hours
    if (hoursUntil <= 48) {
      return UrgencyLevel.high;
    }
    
    // Normal: > 48 hours
    return UrgencyLevel.normal;
  }

  /// Get urgency border color for card visual hierarchy
  static Color getUrgencyBorderColor(DateTime? dueDate) {
    final urgency = getUrgencyLevel(dueDate);
    switch (urgency) {
      case UrgencyLevel.urgent:
        return const Color(0xFFDC2626);  // Red
      case UrgencyLevel.high:
        return const Color(0xFFF97316);  // Orange
      case UrgencyLevel.normal:
        return Colors.grey.shade400;  // Gray (neutral)
    }
  }

  /// Get urgency border width (thicker for urgent)
  static double getUrgencyBorderWidth(DateTime? dueDate) {
    final urgency = getUrgencyLevel(dueDate);
    return urgency == UrgencyLevel.urgent ? 2.0 : 1.0;
  }
}
