import 'package:trial1/models/academic_models.dart';

class UnifiedDashboardData {
  final List<AcademicItem> focus;
  final Map<String, List<AcademicItem>> grouped;
  final List<AcademicItem> timelineItems;
  final List<Map<String, dynamic>> timelineGroups;
  final Map<String, dynamic>? banner;

  UnifiedDashboardData({
    required this.focus,
    required this.grouped,
    required this.timelineItems,
    required this.timelineGroups,
    this.banner,
  });

  // Helper to convert minimal dashboard item JSON into AcademicItem
  static AcademicItem _toAcademicItem(Map<String, dynamic> json) {
    DateTime? due;
    if (json['due_date'] != null) {
      try {
        due = DateTime.parse(json['due_date'] as String).toLocal();
      } catch (_) {
        due = null;
      }
    }

    return AcademicItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      sourceEmailId: json['source_email_id'] as String? ?? '',
      entityType:
          (json['entity_type'] as String?) ??
          (json['type'] as String?) ??
          'INFORMATION',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      dueDate: due,
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
                .map((m) => FollowUp.fromJson(m))
                .toList()
          : null,
    );
  }

  factory UnifiedDashboardData.fromJson(Map<String, dynamic> json) {
    // focus: may be an object or null
    final focusObj = json['focus'];
    final focusList = <AcademicItem>[];
    if (focusObj != null) {
      if (focusObj is List) {
        for (var e in focusObj) {
          if (e is Map<String, dynamic>) focusList.add(_toAcademicItem(e));
        }
      } else if (focusObj is Map<String, dynamic>) {
        focusList.add(_toAcademicItem(focusObj));
      }
    }

    // groups: map of arrays
    final groupedRaw = json['groups'] as Map<String, dynamic>? ?? {};
    final groupedMap = <String, List<AcademicItem>>{};
    for (final key in [
      'ASSIGNMENT',
      'EXAM',
      'ACADEMIC_ADMIN',
      'OPPORTUNITY',
      'INFORMATION',
    ]) {
      final listRaw = groupedRaw[key] as List<dynamic>? ?? [];
      groupedMap[key] = listRaw
          .whereType<Map<String, dynamic>>()
          .map(_toAcademicItem)
          .toList();
    }

    // timeline: list of {date, items: [{id,title,time,type}]}
    final timelineRaw = json['timeline'] as List<dynamic>? ?? [];
    final timelineItems = <AcademicItem>[];
    final timelineGroups = <Map<String, dynamic>>[];
    for (final group in timelineRaw) {
      if (group is Map<String, dynamic>) {
        timelineGroups.add(group);
        final items = group['items'] as List<dynamic>? ?? [];
        for (final it in items) {
          if (it is Map<String, dynamic>) {
            // map timeline event to AcademicItem
            final mapAsItem = <String, dynamic>{
              'id': it['id'] is String
                  ? int.tryParse(
                          (it['id'] as String).replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          ),
                        ) ??
                        0
                  : it['id'],
              'title': it['title'],
              'entity_type': it['type'],
              'due_date': it['time'],
            };
            timelineItems.add(_toAcademicItem(mapAsItem));
          }
        }
      }
    }

    final bannerObj = json['banner'] as Map<String, dynamic>?;

    return UnifiedDashboardData(
      focus: focusList,
      grouped: groupedMap,
      timelineItems: timelineItems,
      timelineGroups: timelineGroups,
      banner: bannerObj,
    );
  }
}
