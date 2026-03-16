/// Structured insights extracted from email (instructor, course, action items).
/// Populated by backend AcademicContextEngine enrichment.
import 'package:trial1/models/gmail_models.dart' show StructuredInsights;

enum AcademicEventType { assignment, exam, academic, opportunity, information, other }

/// Unified academic event model consolidating email notifications into actionable items.
///
/// This represents a single academic event (deadline, announcement, etc.) derived from
/// email metadata enriched by AI classification. Organized by urgency and type for dashboard
/// prioritization. Optionally includes structured insights (instructor, course, actions).
class AcademicEvent {
  final String id; // Gmail message ID
  final AcademicEventType type; // Classified category
  final String title; // Email subject
  final String? course; // Extracted course code (if any)
  final DateTime? deadline; // Extracted deadline
  final String urgency; // Critical / High / Medium / Low / None
  final double academicScore; // Priority score from AI (0.0-100.0)
  final String sourceEmailId; // Unique Gmail ID for detail lookup
  final String summary; // Email snippet/preview text
  final String sender; // Email sender address
  final DateTime? receivedAt; // Email received timestamp
  final StructuredInsights? insights; // Optional deep enrichment (instructor, actions, etc.)

  const AcademicEvent({
    required this.id,
    required this.type,
    required this.title,
    this.course,
    this.deadline,
    required this.urgency,
    required this.academicScore,
    required this.sourceEmailId,
    required this.summary,
    required this.sender,
    this.receivedAt,
    this.insights,
  });

  /// Sort key: combines urgency (hierarchical priority) + academicScore for consistent ordering.
  /// Higher values = higher priority = appear first.
  double get sortKey {
    const urgencyWeights = {
      'Critical': 400.0,
      'High': 300.0,
      'Medium': 200.0,
      'Low': 100.0,
      'None': 0.0,
    };
    final urgencyBase = urgencyWeights[urgency] ?? 0.0;
    return urgencyBase + academicScore;
  }

  /// Check if event is still actionable (deadline not yet passed by > 1 hour).
  bool get isActive {
    if (deadline == null) return true; // No deadline = always active
    final overdue = DateTime.now().difference(deadline!).inHours;
    return overdue <= 1;
  }

  @override
  String toString() => 'AcademicEvent(id: $id, type: $type, title: $title, urgency: $urgency, score: $academicScore)';
}
