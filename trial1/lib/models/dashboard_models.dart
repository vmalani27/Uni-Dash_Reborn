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
    final rawDue = json['due_date'] ?? json['due_at'];
    if (rawDue != null) {
      try {
        due = DateTime.parse(rawDue as String).toLocal();
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
          (json['category'] as String?) ??
          (json['type'] as String?) ??
          'INFORMATION',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      dueDate: due,
      location: json['location'] as String?,
      courseCode: json['course_code'] as String?,
      professor: json['professor'] as String?,
      academicScore:
          (json['effective_score'] as num?)?.toDouble() ??
          (json['academic_score'] as num?)?.toDouble() ??
          (json['priority'] as num?)?.toDouble() ??
          0.0,
      completed: json['completed'] as bool? ?? false,
      dismissed: json['dismissed'] as bool? ?? false,
      status: json['status'] as String?,
      rawAcademicScore: (json['raw_academic_score'] as num?)?.toDouble(),
      effectiveScore: (json['effective_score'] as num?)?.toDouble(),
      decayFactor: (json['decay_factor'] as num?)?.toDouble(),
      lastUpdatedAt: json['last_updated_at'] != null
          ? DateTime.parse(json['last_updated_at'] as String).toLocal()
          : null,
      snoozedUntil: json['snoozed_until'] != null
          ? DateTime.parse(json['snoozed_until'] as String).toLocal()
          : null,
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
    const dashboardKeys = [
      'ASSIGNMENT',
      'EXAM',
      'ACADEMIC_ADMIN',
      'OPPORTUNITY',
      'INFORMATION',
    ];

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

    final academicItemsRaw = json['academic_items'] as List<dynamic>? ?? [];
    final academicItems = <AcademicItem>[];
    for (final item in academicItemsRaw) {
      if (item is Map<String, dynamic>) {
        academicItems.add(_toAcademicItem(item));
      }
    }

    // groups: map of arrays
    final groupedRaw = json['groups'] as Map<String, dynamic>? ?? {};
    final groupedMap = <String, List<AcademicItem>>{};
    for (final key in dashboardKeys) {
      final listRaw = groupedRaw[key] as List<dynamic>? ?? [];
      groupedMap[key] = listRaw
          .whereType<Map<String, dynamic>>()
          .map(_toAcademicItem)
          .toList();
    }

    final hasGroupedItems = groupedMap.values.any((items) => items.isNotEmpty);
    if (!hasGroupedItems && academicItems.isNotEmpty) {
      for (final item in academicItems) {
        final key = dashboardKeys.contains(item.entityType.toUpperCase())
            ? item.entityType.toUpperCase()
            : 'INFORMATION';
        groupedMap[key]!.add(item);
      }
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

    if (timelineGroups.isEmpty && academicItems.isNotEmpty) {
      final buckets = <String, List<Map<String, dynamic>>>{
        'Today': [],
        'Tomorrow': [],
        'This Week': [],
      };
      final now = DateTime.now();

      for (final item in academicItems) {
        final dueDate = item.dueDate;
        if (dueDate == null) continue;

        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final today = DateTime(now.year, now.month, now.day);
        final deltaDays = dueDay.difference(today).inDays;

        String? bucket;
        if (deltaDays == 0) {
          bucket = 'Today';
        } else if (deltaDays == 1) {
          bucket = 'Tomorrow';
        } else if (deltaDays > 1 && deltaDays <= 7) {
          bucket = 'This Week';
        }

        if (bucket == null) continue;

        timelineItems.add(item);
        buckets[bucket]!.add({
          'id': 'item-${item.id}',
          'title': item.title,
          'time': dueDate.toIso8601String(),
          'type': item.entityType,
        });
      }

      for (final key in ['Today', 'Tomorrow', 'This Week']) {
        timelineGroups.add({'date': key, 'items': buckets[key]});
      }
    }

    final bannerObj = json['banner'] as Map<String, dynamic>?;
    if (focusList.isEmpty && academicItems.isNotEmpty) {
      focusList.add(academicItems.first);
    }

    return UnifiedDashboardData(
      focus: focusList,
      grouped: groupedMap,
      timelineItems: timelineItems,
      timelineGroups: timelineGroups,
      banner: bannerObj,
    );
  }
}

