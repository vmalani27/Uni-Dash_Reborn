class AcademicItem {
  final int id;
  final String sourceEmailId;
  final String entityType;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String? location;
  final String? courseCode;
  final String? professor;
  final double academicScore;
  final bool completed;
  // Optional AI/enrichment fields
  final String? aiSummary;
  final String? aiLabelTopic;
  final String? aiLabelSource;
  final List<FollowUp>? followUps;

  AcademicItem({
    required this.id,
    required this.sourceEmailId,
    required this.entityType,
    required this.title,
    required this.description,
    this.dueDate,
    this.location,
    this.courseCode,
    this.professor,
    required this.academicScore,
    required this.completed,
    this.aiSummary,
    this.aiLabelTopic,
    this.aiLabelSource,
    this.followUps,
  });

  factory AcademicItem.fromJson(Map<String, dynamic> json) {
    return AcademicItem(
      id: json['id'] as int,
      sourceEmailId: json['source_email_id'] as String,
      entityType: json['entity_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String).toLocal()
          : null,
      location: json['location'] as String?,
      courseCode: json['course_code'] as String?,
      professor: json['professor'] as String?,
      academicScore: (json['academic_score'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as bool? ?? false,
      aiSummary: json['ai_summary'] as String?,
      aiLabelTopic: json['ai_label_topic'] as String?,
      aiLabelSource: json['ai_label_source'] as String?,
      followUps: json['follow_ups'] is List
          ? (json['follow_ups'] as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map(FollowUp.fromJson)
                .toList()
          : null,
    );
  }
}

class FollowUp {
  final int id;
  final String sourceEmailId;
  final DateTime? triggerAt;
  final String message;
  final String emailSubject;
  final String emailTopic;

  FollowUp({
    required this.id,
    required this.sourceEmailId,
    this.triggerAt,
    required this.message,
    required this.emailSubject,
    required this.emailTopic,
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    return FollowUp(
      id: json['id'] as int,
      sourceEmailId: json['source_email_id'] as String,
      triggerAt: json['trigger_at'] != null
          ? DateTime.parse(json['trigger_at'] as String).toLocal()
          : null,
      message: json['message'] as String,
      emailSubject: json['email_subject'] as String? ?? 'Email',
      emailTopic:
          json['email_topic'] as String? ?? 'General Information / Misc',
    );
  }
}
