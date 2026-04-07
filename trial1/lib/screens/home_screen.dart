import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/focus_card.dart';
import 'package:trial1/widgets/dashboard/category_overview.dart';
import 'package:trial1/models/academic_event.dart';
import 'package:trial1/widgets/dashboard/vertical_sections.dart';
import 'package:trial1/widgets/timeline_section.dart';
import 'package:trial1/widgets/timeline_compact.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/models/dashboard_models.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? themeToggle;
  final ThemeMode? themeMode;

  const HomeScreen({super.key, this.themeToggle, this.themeMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _DashboardSnapshot {
  final Map<String, dynamic> raw;

  const _DashboardSnapshot({required this.raw});
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _pollInterval = Duration(seconds: 30);

  late final Future<Map<String, dynamic>> _profileFuture;
  final ValueNotifier<_DashboardSnapshot?> _dashboardSnapshot =
      ValueNotifier<_DashboardSnapshot?>(null);

  Timer? _pollTimer;
  String? _lastFingerprint;
  bool _dashboardLoading = true;
  bool _refreshInFlight = false;
  String? _dashboardError;

  @override
  void initState() {
    super.initState();
    _profileFuture = BackendService.fetchUserProfile();
    _profileFuture
        .then((profile) {
          if (!mounted) return;
          if (_isOauthConnected(profile)) {
            _startPolling();
            unawaited(_refreshDashboard(force: true));
          } else {
            setState(() {
              _dashboardLoading = false;
              _dashboardError = null;
            });
          }
        })
        .catchError((_) {
          // The FutureBuilder below renders the actual profile error state.
        });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dashboardSnapshot.dispose();
    super.dispose();
  }

  bool _isOauthConnected(Map<String, dynamic> profile) {
    return profile['oauth_connected'] == true ||
        profile['oauth_connected'] == 1;
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(_refreshDashboard());
    });
  }

  Future<void> _refreshDashboard({bool force = false}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    final shouldUpdateLoadingState =
        _dashboardLoading || _dashboardError != null;

    try {
      final data = await BackendService.fetchUnifiedDashboard();
      final fingerprint = _dashboardFingerprint(data);

      if (force || fingerprint != _lastFingerprint) {
        _lastFingerprint = fingerprint;
        _dashboardSnapshot.value = _DashboardSnapshot(raw: data);
      }

      if (mounted && shouldUpdateLoadingState) {
        setState(() {
          _dashboardLoading = false;
          _dashboardError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_dashboardSnapshot.value == null || _dashboardError != null) {
        setState(() {
          _dashboardLoading = false;
          _dashboardError = 'Failed to load dashboard: $e';
        });
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  String _dashboardFingerprint(Map<String, dynamic> data) {
    final buffer = StringBuffer();

    void addItem(Map<String, dynamic> item) {
      buffer.write('${item['id'] ?? ''}|');
      buffer.write('${item['last_updated_at'] ?? ''}|');
      buffer.write('${item['status'] ?? ''}|');
      buffer.write(
        '${item['effective_score'] ?? item['academic_score'] ?? ''}|',
      );
      buffer.write('${item['dismissed'] ?? false}|');
      buffer.write('${item['completed'] ?? false};');
    }

    final focus = data['focus'];
    if (focus is List) {
      for (final item in focus.whereType<Map<String, dynamic>>()) {
        addItem(item);
      }
    } else if (focus is Map<String, dynamic>) {
      addItem(focus);
    }

    final grouped = data['groups'];
    if (grouped is Map<String, dynamic>) {
      for (final key in [
        'ASSIGNMENT',
        'EXAM',
        'ACADEMIC_ADMIN',
        'OPPORTUNITY',
        'INFORMATION',
      ]) {
        final groupItems = grouped[key];
        if (groupItems is List) {
          for (final item in groupItems.whereType<Map<String, dynamic>>()) {
            addItem(item);
          }
        }
      }
    }

    final academicItems = data['academic_items'];
    if (academicItems is List) {
      for (final item in academicItems.whereType<Map<String, dynamic>>()) {
        addItem(item);
      }
    }

    final banner = data['banner'];
    if (banner is Map<String, dynamic>) {
      buffer.write(
        'banner:${banner['item_id'] ?? ''}|${banner['message'] ?? ''}',
      );
    }

    return buffer.toString();
  }

  Widget _buildLoadingState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final loadingContainer = Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color:
                Theme.of(context).snackBarTheme.backgroundColor ??
                Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.12),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Loading dashboard...',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

        if (isMobile) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                loadingContainer,
                const SizedBox(height: 16),
                const FocusCard(),
                const SizedBox(height: 16),
                VerticalSections(groups: {}),
                const SizedBox(height: 16),
                TimelineSection(groups: [], onItemTap: (_) {}),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 70,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    loadingContainer,
                    const SizedBox(height: 16),
                    const FocusCard(),
                    const SizedBox(height: 16),
                    VerticalSections(groups: {}),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 30,
              child: _buildSecondaryPanel(
                context,
                timelineGroups: [],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Connect Gmail To Unlock Dashboard',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your focus cards, assignments, and exams appear after OAuth is completed.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
              child: const Text('Go To Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Failed to load dashboard',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(error),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                unawaited(_refreshDashboard(force: true));
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryPanel(
    BuildContext context, {
    List<Map<String, dynamic>>? timelineGroups,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color:
              Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.3),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.08),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
              child: Text(
                'Timeline',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: TimelineCompact(
                  groups: timelineGroups ?? [],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftColumn({
    required BuildContext context,
    required Widget focusWidget,
    required Map<String, int> counts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        focusWidget,
        const SizedBox(height: 16),
        CategoryOverview(
          counts: counts,
          onSelect: (label) {
            Navigator.of(
              context,
            ).pushNamed('/dashboard/list', arguments: {'filter': label});
          },
        ),
      ],
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    UnifiedDashboardData data,
  ) {
    final allItems = data.grouped.values.expand((items) => items).toList();

    AcademicItem? topPriorityItem;
    if (allItems.isNotEmpty) {
      final activeItems = allItems.where((item) {
        if (item.dueDate == null) return true;
        final overdueHours = DateTime.now().difference(item.dueDate!).inHours;
        return overdueHours <= 1;
      }).toList();

      final candidateItems = activeItems.isNotEmpty ? activeItems : allItems;
      candidateItems.sort((a, b) {
        final scoreCmp = b.academicScore.compareTo(a.academicScore);
        if (scoreCmp != 0) return scoreCmp;
        final aDue = a.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDue = b.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDue.compareTo(bDue);
      });
      topPriorityItem = candidateItems.first;
    }

    final allEvents = <AcademicEvent>[];
    AcademicEventType mapEntity(String entity) {
      switch (entity.toUpperCase()) {
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

    data.grouped.forEach((_, items) {
      for (final item in items) {
        allEvents.add(
          AcademicEvent(
            id: item.id.toString(),
            type: mapEntity(item.entityType),
            title: item.title,
            course: item.courseCode,
            deadline: item.dueDate,
            urgency: 'Medium',
            academicScore: item.academicScore,
            sourceEmailId: item.sourceEmailId,
            summary:
                (item.aiSummary != null && item.aiSummary!.trim().isNotEmpty)
                ? item.aiSummary!
                : item.description,
            sender: '',
            receivedAt: null,
            insights: null,
          ),
        );
      }
    });

    AcademicEvent? topPriorityEvent;
    final active = allEvents.where((e) => e.isActive).toList();
    if (active.isNotEmpty) {
      active.sort((a, b) => b.academicScore.compareTo(a.academicScore));
      topPriorityEvent = active.first;
    } else {
      final upcoming = allEvents.where((e) => e.isUpcoming).toList();
      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) => b.academicScore.compareTo(a.academicScore));
        topPriorityEvent = upcoming.first;
      }
    }

    int? parseTimelineAcademicItemId(Map<String, dynamic> raw) {
      final id = raw['id'];
      if (id is int) return id;
      final idStr = id?.toString() ?? '';
      if (!idStr.startsWith('item-')) {
        return null;
      }
      return int.tryParse(idStr.replaceFirst('item-', ''));
    }

    Future<void> runTimelineAction(
      Map<String, dynamic> raw,
      Future<void> Function(int) action,
      String successMessage,
    ) async {
      final itemId = parseTimelineAcademicItemId(raw);
      if (itemId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Action available only for academic items.'),
            ),
          );
        }
        return;
      }

      try {
        await action(itemId);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(successMessage)));
        }
        unawaited(_refreshDashboard(force: true));
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
        }
      }
    }

    final focusWidget = FocusCard(
      item: topPriorityItem,
      event: topPriorityItem == null ? topPriorityEvent : null,
    );

    final counts = {
      'Assignments': data.grouped['ASSIGNMENT']?.length ?? 0,
      'Exams': data.grouped['EXAM']?.length ?? 0,
      'Opportunities': data.grouped['OPPORTUNITY']?.length ?? 0,
      'Announcements': data.grouped['ACADEMIC_ADMIN']?.length ?? 0,
    };

    final timelineWidget = TimelineSection(
      groups: data.timelineGroups,
      onMarkCompleted: (raw) => runTimelineAction(
        raw,
        BackendService.markAcademicItemDone,
        'Marked as completed',
      ),
      onAddToCalendar: (raw) => runTimelineAction(
        raw,
        BackendService.addAcademicItemToCalendar,
        'Added to calendar',
      ),
      onDismiss: (raw) => runTimelineAction(
        raw,
        BackendService.dismissAcademicItem,
        'Dismissed',
      ),
      onItemTap: (raw) {
        final title = (raw['title'] != null)
            ? raw['title'].toString()
            : 'Event';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tapped: $title')));
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          // Mobile: single column layout (stacked)
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                focusWidget,
                const SizedBox(height: 16),
                CategoryOverview(
                  counts: counts,
                  onSelect: (label) {
                    Navigator.of(
                      context,
                    ).pushNamed('/dashboard/list', arguments: {'filter': label});
                  },
                ),
                const SizedBox(height: 16),
                timelineWidget,
              ],
            ),
          );
        }

        // Tablet & Desktop: two-column layout
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column (70% flex)
              Expanded(
                flex: 70,
                child: _buildLeftColumn(
                  context: context,
                  focusWidget: focusWidget,
                  counts: counts,
                ),
              ),
              // Right column (30% flex) - timeline sidebar
              Expanded(
                flex: 30,
                child: _buildSecondaryPanel(
                  context,
                  timelineGroups: data.timelineGroups,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniDash'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: widget.themeToggle,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).pushNamed('/profile'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.person, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive horizontal padding based on screen width
          double horizontalPadding;
          if (constraints.maxWidth < 600) {
            horizontalPadding = 16.0; // Mobile
          } else if (constraints.maxWidth < 1200) {
            horizontalPadding = 24.0; // Tablet
          } else if (constraints.maxWidth < 1600) {
            horizontalPadding = 32.0; // Desktop
          } else {
            horizontalPadding = 48.0; // Ultra-wide
          }

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16.0,
            ),
            child: ValueListenableBuilder<_DashboardSnapshot?>(
              valueListenable: _dashboardSnapshot,
              builder: (context, dashboardSnapshot, _) {
                return FutureBuilder<Map<String, dynamic>>(
                  future: _profileFuture,
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.connectionState !=
                        ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (profileSnapshot.hasError ||
                        !profileSnapshot.hasData) {
                      return SingleChildScrollView(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Unable to load profile. Please retry from Profile.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }

                    final profile = profileSnapshot.data!;
                    final oauthConnected = _isOauthConnected(profile);

                    if (!oauthConnected) {
                      return SingleChildScrollView(
                        child: _buildConnectPrompt(context),
                      );
                    }

                    if (_dashboardLoading &&
                        profileSnapshot.data != null &&
                        dashboardSnapshot == null) {
                      return _buildLoadingState(context);
                    }

                    if (_dashboardError != null &&
                        dashboardSnapshot == null) {
                      return SingleChildScrollView(
                        child: _buildDashboardError(context, _dashboardError!),
                      );
                    }

                    final raw = dashboardSnapshot?.raw;
                    if (raw == null) {
                      return _buildLoadingState(context);
                    }

                    final data = UnifiedDashboardData.fromJson(raw);
                    return _buildDashboardContent(context, data);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
