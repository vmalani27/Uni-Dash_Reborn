import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/focus_card.dart';
import 'package:trial1/widgets/rotating_focus_card.dart';
import 'package:trial1/utils/priority_scorer.dart';
import 'package:trial1/widgets/dashboard/category_overview.dart';
import 'package:trial1/widgets/dashboard/bucket_tabs_with_panel.dart';
import 'package:trial1/models/academic_event.dart';
import 'package:trial1/widgets/dashboard/vertical_sections.dart';
import 'package:trial1/widgets/timeline_section.dart';
import 'package:trial1/widgets/timeline_desktop.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/services/dashboard_cache_service.dart';
import 'package:trial1/services/sync_event_service.dart';
import 'package:trial1/models/dashboard_models.dart';
import 'package:trial1/models/sync_ui_state.dart';
import 'package:trial1/widgets/global_search_bar.dart';
import 'package:trial1/widgets/search_results_view.dart';
import 'package:trial1/widgets/context_feed_container.dart';

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
  static const Duration _fallbackPollInterval = Duration(seconds: 60);

  late final Future<Map<String, dynamic>> _profileFuture;
  final ValueNotifier<_DashboardSnapshot?> _dashboardSnapshot =
      ValueNotifier<_DashboardSnapshot?>(null);

  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _sseSubscription;
  Duration? _activePollInterval;
  String? _lastFingerprint;
  bool _dashboardLoading = true;
  bool _refreshInFlight = false;
  bool _sseHealthy = false;
  bool _sseReconnectScheduled = false;
  String? _dashboardError;
  SyncUIState? _syncUiState;
  String _searchQuery = ''; // NEW: track search query

  @override
  void initState() {
    super.initState();
    _profileFuture = BackendService.fetchUserProfile();
    _profileFuture
        .then((profile) {
          if (!mounted) return;
          if (_isOauthConnected(profile)) {
            unawaited(_bootstrapDashboard());
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
    _sseSubscription?.cancel();
    _dashboardSnapshot.dispose();
    super.dispose();
  }

  bool _isOauthConnected(Map<String, dynamic> profile) {
    return profile['oauth_connected'] == true ||
        profile['oauth_connected'] == 1;
  }

  void _startPolling([Duration interval = _fallbackPollInterval]) {
    if (_pollTimer != null && _activePollInterval == interval) {
      return;
    }

    _pollTimer?.cancel();
    _activePollInterval = interval;
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_refreshDashboard());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _activePollInterval = null;
  }

  Future<bool> _loadLocalSnapshot() async {
    final cached = await DashboardCacheService.loadSnapshot();
    if (cached == null) {
      return false;
    }

    final fingerprint = _dashboardFingerprint(cached);
    _lastFingerprint = fingerprint;
    _dashboardSnapshot.value = _DashboardSnapshot(raw: cached);
    return true;
  }

  void _startSseWatcher(String uid) {
    if (_sseSubscription != null) {
      return;
    }

    final stream = SyncEventService.subscribeSyncStatus(uid);
    _sseSubscription = stream.listen(
      (event) {
        _sseHealthy = true;
        _stopPolling();

        final status = event['status']?.toString();
        final pipelineComplete = event['pipeline_complete'] == true;

        if (pipelineComplete || status == 'completed' || status == 'no_action') {
          unawaited(_refreshDashboard(force: true, updateLoadingState: false));
        }
      },
      onError: (_) {
        _sseHealthy = false;
        _sseSubscription?.cancel();
        _sseSubscription = null;
        _startPolling();
        _scheduleSseReconnect(uid);
      },
      onDone: () {
        _sseHealthy = false;
        _sseSubscription = null;
        _startPolling();
        _scheduleSseReconnect(uid);
      },
      cancelOnError: true,
    );
  }

  void _scheduleSseReconnect(String uid) {
    if (_sseReconnectScheduled || !mounted) {
      return;
    }
    _sseReconnectScheduled = true;
    Future<void>.delayed(const Duration(seconds: 5), () {
      _sseReconnectScheduled = false;
      if (!mounted || _sseSubscription != null) {
        return;
      }
      _startSseWatcher(uid);
    });
  }

  Future<void> _bootstrapDashboard() async {
    if (_syncUiState?.isActive == true) return;

    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
      _syncUiState = null;
    });

    try {
      final uid = await BackendService.getCurrentUid();
      final localLoaded = await _loadLocalSnapshot();
      if (!mounted) return;

      if (localLoaded) {
        setState(() {
          _dashboardLoading = false;
          _dashboardError = null;
        });
        _startSseWatcher(uid);
        unawaited(_refreshDashboard(force: true, updateLoadingState: false));
        return;
      }

      final hasServerSnapshot = await _refreshDashboard(
        force: true,
        updateLoadingState: false,
      );
      if (!mounted) return;

      if (hasServerSnapshot && _dashboardSnapshot.value != null) {
        setState(() {
          _dashboardLoading = false;
          _dashboardError = null;
        });
        _startSseWatcher(uid);
        return;
      }

      final syncStatus = await BackendService.fetchGmailSyncStatus(uid);

      if (!mounted) return;

      if (syncStatus == 'in_progress') {
        _startSseWatcher(uid);
      } else {
        await BackendService.triggerIncrementalSync(uid);
        _startSseWatcher(uid);
      }
    } catch (e) {
      if (!mounted) return;
      final failureDetail =
          e is SyncStreamUnavailableException
          ? e.message
          : 'Please try again to restart the sync.';
      setState(() {
        _syncUiState = SyncUIState.failed(detail: failureDetail);
        _dashboardError =
            'We could not finish preparing your dashboard. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _dashboardLoading = false;
        });
      }
    }
  }

  Future<bool> _refreshDashboard({
    bool force = false,
    bool updateLoadingState = true,
  }) async {
    if (_refreshInFlight) return false;

    if (!force && _sseHealthy) {
      return true;
    }

    _refreshInFlight = true;
    final shouldUpdateLoadingState =
        updateLoadingState && (_dashboardLoading || _dashboardError != null);

    try {
      final data = await BackendService.fetchUnifiedDashboard();
      final fingerprint = _dashboardFingerprint(data);

      if (force || fingerprint != _lastFingerprint) {
        _lastFingerprint = fingerprint;
        _dashboardSnapshot.value = _DashboardSnapshot(raw: data);
        await DashboardCacheService.saveSnapshot(data);
      }

      if (mounted && shouldUpdateLoadingState) {
        setState(() {
          _dashboardLoading = false;
          _dashboardError = null;
        });
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (_dashboardSnapshot.value == null || _dashboardError != null) {
        setState(() {
          _dashboardLoading = false;
          _dashboardError = 'Failed to load dashboard: $e';
        });
      }
      return false;
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

  List<AcademicItem> _extractAllItems(_DashboardSnapshot snapshot) {
    final allItems = <AcademicItem>[];
    final seenIds = <int>{};

    // Try to extract from raw data
    final data = snapshot.raw;

    // From focus items
    final focus = data['focus'];
    if (focus is List) {
      for (final item in focus.whereType<Map<String, dynamic>>()) {
        try {
          final academicItem = AcademicItem.fromJson(item);
          if (!seenIds.contains(academicItem.id)) {
            allItems.add(academicItem);
            seenIds.add(academicItem.id);
          }
        } catch (_) {}
      }
    }

    // From grouped items
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
            try {
              final academicItem = AcademicItem.fromJson(item);
              if (!seenIds.contains(academicItem.id)) {
                allItems.add(academicItem);
                seenIds.add(academicItem.id);
              }
            } catch (_) {}
          }
        }
      }
    }

    // From academic items
    final academicItems = data['academic_items'];
    if (academicItems is List) {
      for (final item in academicItems.whereType<Map<String, dynamic>>()) {
        try {
          final academicItem = AcademicItem.fromJson(item);
          if (!seenIds.contains(academicItem.id)) {
            allItems.add(academicItem);
            seenIds.add(academicItem.id);
          }
        } catch (_) {}
      }
    }

    print('[ExtractAllItems] Total unique items: ${allItems.length}');
    return allItems;
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
              child: _buildSecondaryPanel(context, timelineGroups: []),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSyncBootstrapState(BuildContext context, SyncUIState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Icon(
                        state.phase == SyncUIPhase.ready
                            ? Icons.check_rounded
                            : state.phase == SyncUIPhase.failed ||
                                  state.phase == SyncUIPhase.timeout
                            ? Icons.refresh_rounded
                            : Icons.cloud_sync,
                        color: Theme.of(context).colorScheme.primary,
                        size: 30,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                state.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                state.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.72),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                state.detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.56),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: state.progress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: value.clamp(0.0, 1.0),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: state.isActive
                    ? null
                    : () {
                        unawaited(_bootstrapDashboard());
                      },
                child: const Text('Retry sync'),
              ),
            ],
          ),
        ),
      ),
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
                unawaited(_bootstrapDashboard());
              },
              child: const Text('Retry sync'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryPanel(
    BuildContext context, {
    List<Map<String, dynamic>>? timelineGroups,
    List<AcademicItem>? informationItems,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainer.withOpacity(0.3),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.08),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline section
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Timeline',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: TimelineDesktop(
                  groups: timelineGroups ?? [],
                  onItemTap: (item) {
                    // Handle timeline item tap
                  },
                ),
              ),

              // Separator between Timeline and Context Feed
              if (informationItems != null && informationItems.isNotEmpty)
                const SizedBox(height: 12),

              // Context Feed section
              if (informationItems != null && informationItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ContextFeedContainer(
                    informationItems: informationItems,
                    onItemDismissed: () {
                      // Trigger refresh if needed
                    },
                    onItemTapped: (item) {
                      // Handle item tap (e.g., show preview dialog)
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn({
    required BuildContext context,
    required Widget focusWidget,
    required Map<String, int> counts,
    required Map<String, List<AcademicItem>> groupedItems,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        focusWidget,
        const SizedBox(height: 16),
        BucketTabsWithPanel(counts: counts, groupedItems: groupedItems),
      ],
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    UnifiedDashboardData data,
  ) {
    // NEW: Check if user is searching
    if (_searchQuery.isNotEmpty && _dashboardSnapshot.value != null) {
      final allItems = _extractAllItems(_dashboardSnapshot.value!);

      return LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          if (isMobile) {
            return SearchResultsView(
              query: _searchQuery,
              allItems: allItems,
              onResultTap: (item) {
                setState(() => _searchQuery = '');
                unawaited(_refreshDashboard(force: true));
              },
            );
          }

          // Tablet & Desktop: show results on left, timeline on right
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 70,
                child: SearchResultsView(
                  query: _searchQuery,
                  allItems: allItems,
                  onResultTap: (item) {
                    setState(() => _searchQuery = '');
                    unawaited(_refreshDashboard(force: true));
                  },
                ),
              ),
              Expanded(
                flex: 30,
                child: _buildSecondaryPanel(
                  context,
                  timelineGroups: data.timelineGroups,
                  informationItems: data.grouped['INFORMATION'] ?? [],
                ),
              ),
            ],
          );
        },
      );
    }

    // EXISTING: Normal dashboard mode (non-search)
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

    final active = allEvents.where((e) => e.isActive).toList();
    if (active.isNotEmpty) {
      active.sort((a, b) => b.academicScore.compareTo(a.academicScore));
    } else {
      final upcoming = allEvents.where((e) => e.isUpcoming).toList();
      if (upcoming.isNotEmpty) {
        upcoming.sort((a, b) => b.academicScore.compareTo(a.academicScore));
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

    // Collect top priority items for focus card rotation
    final focusItemsRaw = data.grouped.values.expand((items) => items).toList();
    final focusItems = PriorityScorer.selectFocusItems(focusItemsRaw, limit: 5);

    final focusWidget = focusItems.isNotEmpty
        ? RotatingFocusCard(
            focusItems: focusItems,
            onActionCompleted: () => unawaited(_refreshDashboard(force: true)),
            onActionDismissed: () => unawaited(_refreshDashboard(force: true)),
          )
        : const FocusCard();

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
                    Navigator.of(context).pushNamed(
                      '/dashboard/list',
                      arguments: {'filter': label},
                    );
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
                  groupedItems: data.grouped,
                ),
              ),
              // Right column (30% flex) - timeline sidebar
              Expanded(
                flex: 30,
                child: _buildSecondaryPanel(
                  context,
                  timelineGroups: data.timelineGroups,
                  informationItems: data.grouped['INFORMATION'] ?? [],
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
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              // Left: App title
              const Text(
                'UniDash',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 24),
              // Center: Search bar
              Expanded(
                child: ValueListenableBuilder<_DashboardSnapshot?>(
                  valueListenable: _dashboardSnapshot,
                  builder: (context, snapshot, _) {
                    // Extract all academic items from the dashboard
                    final allItems = snapshot != null
                        ? _extractAllItems(snapshot)
                        : <AcademicItem>[];

                    return GlobalSearchBar(
                      academicItems: allItems,
                      onResultSelected: () {
                        // Trigger dashboard refresh when a search result is selected
                        unawaited(_refreshDashboard(force: true));
                      },
                      onSearchQueryChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Right: Action icons
              IconButton(
                icon: Icon(
                  widget.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: widget.themeToggle,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
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
        ),
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

                    if (profileSnapshot.hasError || !profileSnapshot.hasData) {
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

                    if (_dashboardError != null && dashboardSnapshot == null) {
                      return SingleChildScrollView(
                        child: _buildDashboardError(context, _dashboardError!),
                      );
                    }

                    if (_syncUiState != null && dashboardSnapshot == null) {
                      return _buildSyncBootstrapState(context, _syncUiState!);
                    }

                    if (_dashboardLoading &&
                        profileSnapshot.data != null &&
                        dashboardSnapshot == null) {
                      return _buildLoadingState(context);
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
