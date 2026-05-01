import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/models/academic_event.dart';

/// Converts normalized topic strings to AcademicEventType enum.
AcademicEventType _topicToType(String normalizedTopic) {
  switch (normalizedTopic.toUpperCase()) {
    case 'ASSIGNMENT':
      return AcademicEventType.assignment;
    case 'EXAM':
      return AcademicEventType.exam;
    case 'ACADEMIC_ADMIN':
      return AcademicEventType.academic;
    case 'OPPORTUNITY':
      return AcademicEventType.opportunity;
    case 'INFORMATION':
      return AcademicEventType.information;
    default:
      return AcademicEventType.other;
  }
}

/// Extracts course code from email subject using regex patterns.
/// Looks for patterns like "CS101", "CS 101", "MATH-201", "CSC 151".
String? _extractCourse(String? subject) {
  if (subject == null || subject.isEmpty) return null;

  // Common course code patterns: Letter(s) + optional space + Numbers
  final patterns = [
    RegExp(r'\b([A-Z]{2,4}\s?\d{3,4})\b'), // CS 101, MATH 201
    RegExp(r'\b([A-Z]{2,}\-\d{3,4})\b'), // CSC-151
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(subject);
    if (match != null) {
      return match.group(1)?.replaceAll(' ', '').toUpperCase();
    }
  }

  return null;
}

/// Maps a GmailNotificationPreview to an AcademicEvent.
///
/// Key transformations:
/// - topic → type (enum conversion)
/// - subject + snippet → title + summary
/// - subject → course extraction (or from enriched insights)
/// - Gmail ID preserved for detail lookup
/// - Urgency defaults to 'Medium' if not available (placeholder for future AI enrichment)
/// - structuredInsights passed through for instructor/course/actions
AcademicEvent mapNotificationToEvent(GmailNotificationPreview notification) {
  // Default urgency to 'Medium' — in future, this can come from AI label or rule engine
  const defaultUrgency = 'Medium';

  return AcademicEvent(
    id: notification.gmailId,
    type: _topicToType(notification.normalizedTopic),
    title: notification.subject.isNotEmpty ? notification.subject : 'Untitled Email',
    course: notification.structuredInsights?.courseCode ?? _extractCourse(notification.subject),
    deadline: notification.deadlineIso,
    urgency: defaultUrgency,
    academicScore: notification.academicScore.clamp(0.0, 100.0),
    sourceEmailId: notification.gmailId,
    summary: notification.snippet.isNotEmpty ? notification.snippet : '(No preview)',
    sender: notification.sender,
    receivedAt: notification.internalDate,
    insights: notification.structuredInsights,
  );
}

/// Converts a list of notifications to academic events with stable sorting.
///
/// Sorting order:
/// 1. By urgency + academicScore (combined sort key)
/// 2. Then by deadline (soonest first)
/// 3. Then by recency (newest first)
List<AcademicEvent> mapNotificationsToEvents(List<GmailNotificationPreview> notifications) {
  final events = notifications.map(mapNotificationToEvent).toList();

  // Helper to order lifecycle buckets: ACTIVE < UPCOMING < EXPIRED (lower value = higher priority)
  int _lifecycleOrder(AcademicEvent e) {
    if (e.isActive) return 0;
    if (e.isUpcoming) return 1;
    return 2; // expired
  }

  // Sort: first by lifecycle bucket, then by sortKey (urgency+score), then deadline, then recency
  events.sort((a, b) {
    final lifecycleA = _lifecycleOrder(a);
    final lifecycleB = _lifecycleOrder(b);
    if (lifecycleA != lifecycleB) return lifecycleA.compareTo(lifecycleB);

    // Within same lifecycle, keep existing priority ordering
    if (a.sortKey != b.sortKey) {
      return b.sortKey.compareTo(a.sortKey); // higher sortKey first
    }

    // Then deadline (nearest first)
    if (a.deadline != null && b.deadline != null) {
      return a.deadline!.compareTo(b.deadline!);
    }
    if (a.deadline != null) return -1;
    if (b.deadline != null) return 1;

    // Finally recency (newest first)
    if (a.receivedAt != null && b.receivedAt != null) {
      return b.receivedAt!.compareTo(a.receivedAt!);
    }
    return 0;
  });

  return events;
}

/// Groups events by type for organized dashboard view.
///
/// Returns a map: { type → [sorted events] }
/// Maintains order within each type from mapNotificationsToEvents sorting.
Map<AcademicEventType, List<AcademicEvent>> groupEventsByType(List<AcademicEvent> events) {
  final grouped = <AcademicEventType, List<AcademicEvent>>{};

  for (final event in events) {
    grouped.putIfAbsent(event.type, () => []).add(event);
  }

  return grouped;
}

/// Returns type order for dashboard display.
const List<AcademicEventType> typeDisplayOrder = [
  AcademicEventType.assignment,
  AcademicEventType.exam,
  AcademicEventType.academic,
  AcademicEventType.opportunity,
  AcademicEventType.information,
  AcademicEventType.other,
];

