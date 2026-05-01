import 'package:trial1/models/academic_models.dart';

/// Time tier for academic items based on deadline proximity
enum TimeTier { overdue, today, tomorrow, thisWeek, later }

/// Unified priority scoring for academic items.
/// Used by focus card, timeline, and other urgency-aware components.
class PriorityScorer {
  /// Category priority order (higher = more urgent)
  static const Map<String, int> categoryPriority = {
    'EXAM': 4,
    'ASSIGNMENT': 3,
    'OPPORTUNITY': 2,
    'ACADEMIC_ADMIN': 1,
    'INFORMATION': 0,
  };

  /// Calculate urgency score based on deadline proximity.
  /// Higher score = more urgent.
  static int getUrgencyScore(DateTime? dueDate) {
    if (dueDate == null) {
      return 0; // No deadline = lowest urgency
    }

    final now = DateTime.now();
    final duration = dueDate.difference(now);

    // Items in the past = highest urgency (overdue)
    if (duration.inHours < 0) {
      return 100; // Overdue
    }

    // Within 24 hours = highest priority
    if (duration.inHours < 24) {
      return 90;
    }

    // Within 72 hours (3 days) = high priority
    if (duration.inHours < 72) {
      return 70;
    }

    // Within 7 days = medium priority
    if (duration.inDays < 7) {
      return 50;
    }

    // Beyond 7 days = low priority
    return 20;
  }

  /// Get category priority (0-4)
  static int getCategoryScore(String? entityType) {
    final key = entityType?.toUpperCase() ?? 'INFORMATION';
    return categoryPriority[key] ?? 0;
  }

  /// Combined priority score for sorting.
  /// Higher score = should appear first.
  static int getPriorityScore(AcademicItem item) {
    final urgency = getUrgencyScore(item.dueDate);
    final category = getCategoryScore(item.entityType);
    
    // Weighted: urgency (70%) + category (30%)
    return (urgency * 7 + category * 3) ~/ 10;
  }

  /// Get relative time tier for an item.
  /// Used for tiered selection logic.
  static TimeTier getTimeTier(DateTime? dueDate) {
    if (dueDate == null) {
      return TimeTier.later;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDay.isBefore(today)) {
      return TimeTier.overdue;
    } else if (dueDay == today) {
      return TimeTier.today;
    } else if (dueDay == tomorrow) {
      return TimeTier.tomorrow;
    } else if (dueDay.isBefore(weekEnd)) {
      return TimeTier.thisWeek;
    }

    return TimeTier.later;
  }

  /// Get items filtered by tier, ordered by priority.
  /// Implements tiered selection: today → tomorrow → this week → others → overdue
  static List<AcademicItem> getItemsByTier(
    List<AcademicItem> items,
  ) {
    // Group by time tier
    final Map<TimeTier, List<AcademicItem>> tierGroups = {
      TimeTier.overdue: [],
      TimeTier.today: [],
      TimeTier.tomorrow: [],
      TimeTier.thisWeek: [],
      TimeTier.later: [],
    };

    for (var item in items) {
      final tier = getTimeTier(item.dueDate);
      tierGroups[tier]!.add(item);
    }

    // Sort each tier by priority
    for (var tier in tierGroups.keys) {
      tierGroups[tier]!.sort(
        (a, b) => getPriorityScore(b).compareTo(getPriorityScore(a)),
      );
    }

    // Return in order: today → tomorrow → this week → later → overdue
    // (Overdue at end for visibility, but marked as most urgent)
    return [
      ...tierGroups[TimeTier.today]!,
      ...tierGroups[TimeTier.tomorrow]!,
      ...tierGroups[TimeTier.thisWeek]!,
      ...tierGroups[TimeTier.later]!,
      ...tierGroups[TimeTier.overdue]!,
    ];
  }

  /// Select focus items using tiered logic.
  /// If "today" items exist, use only those
  /// Else if "tomorrow" items exist, use those
  /// Etc., falling back to all items.
  static List<AcademicItem> selectFocusItems(
    List<AcademicItem> items, {
    int limit = 5,
  }) {
    if (items.isEmpty) return [];

    // Get all items sorted by tier and priority
    final sortedByTier = getItemsByTier(items);

    // Try to select from today first
    final todayItems = sortedByTier
        .where((item) => getTimeTier(item.dueDate) == TimeTier.today)
        .toList();
    if (todayItems.isNotEmpty) {
      return todayItems.take(limit).toList();
    }

    // Fallback to tomorrow
    final tomorrowItems = sortedByTier
        .where((item) => getTimeTier(item.dueDate) == TimeTier.tomorrow)
        .toList();
    if (tomorrowItems.isNotEmpty) {
      return tomorrowItems.take(limit).toList();
    }

    // Fallback to this week
    final thisWeekItems = sortedByTier
        .where((item) => getTimeTier(item.dueDate) == TimeTier.thisWeek)
        .toList();
    if (thisWeekItems.isNotEmpty) {
      return thisWeekItems.take(limit).toList();
    }

    // Fallback to all (sorted by priority)
    return sortedByTier.take(limit).toList();
  }
}

