/// Structured insights extracted from email (instructor, course, action items).
/// Populated by backend AcademicContextEngine enrichment.
class StructuredInsights {
  final String? instructorName;
  final String? instructorEmail;
  final String? courseCode;
  final String? courseName;
  final List<String> actionItems; // What student needs to do
  final bool submissionRequired;
  final String? submissionFormat; // e.g., 'PDF', 'Code', 'ZIP'
  final double confidence; // 0.0-1.0
  final bool enrichedByLlm; // true if small LLM was used

  const StructuredInsights({
    this.instructorName,
    this.instructorEmail,
    this.courseCode,
    this.courseName,
    this.actionItems = const [],
    this.submissionRequired = false,
    this.submissionFormat,
    this.confidence = 0.6,
    this.enrichedByLlm = false,
  });

  factory StructuredInsights.fromJson(Map<String, dynamic> json) {
    return StructuredInsights(
      instructorName: json['instructor_name'] as String?,
      instructorEmail: json['instructor_email'] as String?,
      courseCode: json['course_code'] as String?,
      courseName: json['course_name'] as String?,
      actionItems: (json['action_items'] as List?)?.map((e) => e.toString()).toList() ?? [],
      submissionRequired: json['submission_required'] as bool? ?? false,
      submissionFormat: json['submission_format'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.6,
      enrichedByLlm: json['enriched_by_llm'] as bool? ?? false,
    );
  }
}

class GmailNotificationPreview {
  final int id;
  final String gmailId;
  final String sender;
  final String subject;
  final String snippet;
  final DateTime? internalDate;
  final DateTime? deadlineIso;
  final String? deadlineConfidence;
  final double academicScore;
  final String normalizedTopic; // ASSIGNMENT, EXAM, ACADEMIC_ADMIN, OPPORTUNITY, INFORMATION, OTHER
  final StructuredInsights? structuredInsights; // Optional enrichment from backend

  GmailNotificationPreview({
    required this.id,
    required this.gmailId,
    required this.sender,
    required this.subject,
    required this.snippet,
    this.internalDate,
    this.deadlineIso,
    this.deadlineConfidence,
    required this.academicScore,
    required this.normalizedTopic,
    this.structuredInsights,
  });

  factory GmailNotificationPreview.fromJson(Map<String, dynamic> json) {
    return GmailNotificationPreview(
      id: json['id'] as int,
      gmailId: json['gmail_id'] as String,
      sender: json['sender'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      internalDate: json['internal_date'] != null
          ? DateTime.tryParse(json['internal_date'])
          : null,
      deadlineIso: json['deadline_iso'] != null
          ? DateTime.tryParse(json['deadline_iso'])
          : null,
      deadlineConfidence: json['deadline_confidence'] as String?,
      academicScore: (json['academic_score'] as num?)?.toDouble() ?? 0.0,
      normalizedTopic: json['normalized_topic'] as String? ?? 'OTHER',
      structuredInsights: json['structured_insights'] != null
          ? StructuredInsights.fromJson(json['structured_insights'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  String toString() {
    return 'GmailNotificationPreview(id: $id, gmailId: $gmailId, sender: $sender, subject: $subject, snippet: $snippet, internalDate: $internalDate)';
  }
}

class GmailMessageDetail {
  final int? id; // Made optional since backend doesn't provide it
  final String gmailId;
  final String? threadId;
  final String sender;
  final String subject;
  final String bodyHtml;
  final String bodyText;
  final DateTime? internalDate;

  // AI fields
  final String? aiSummary;
  final String? aiLabelTopic;
  final String? aiLabelUrgency;
  final String? aiLabelSource;
  final bool aiProcessed;

  // Deadline and priority fields
  final DateTime? deadlineIso;
  final String? deadlineConfidence;
  final double academicScore;

  GmailMessageDetail({
    this.id, // Made optional
    required this.gmailId,
    this.threadId,
    required this.sender,
    required this.subject,
    required this.bodyHtml,
    required this.bodyText,
    this.internalDate,
    this.aiSummary,
    this.aiLabelTopic,
    this.aiLabelUrgency,
    this.aiLabelSource,
    this.aiProcessed = false,
    this.deadlineIso,
    this.deadlineConfidence,
    required this.academicScore,
  });

  factory GmailMessageDetail.fromJson(Map<String, dynamic> json) {
    return GmailMessageDetail(
      id: json['id'] as int?, // Made nullable
      gmailId: json['gmail_id'] as String,
      threadId: json['thread_id'] as String?,
      sender: json['sender'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      bodyHtml: json['body_html'] as String? ?? '',
      bodyText: json['body_text'] as String? ?? '',
      internalDate: json['internal_date'] != null
          ? DateTime.tryParse(json['internal_date'])
          : null,
      aiSummary: json['ai_summary'] as String?,
      aiLabelTopic: json['ai_label_topic'] as String?,
      aiLabelUrgency: json['ai_label_urgency'] as String?,
      aiLabelSource: json['ai_label_source'] as String?,
      aiProcessed: json['ai_processed'] as bool? ?? false,
      deadlineIso: json['deadline_iso'] != null
          ? DateTime.tryParse(json['deadline_iso'])
          : null,
      deadlineConfidence: json['deadline_confidence'] as String?,
      academicScore: (json['academic_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
