import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/screens/connect_gmail_screen.dart';
import 'package:trial1/screens/profile_screen.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/focus_card.dart';
import 'package:trial1/widgets/timeline_section.dart';
import 'package:trial1/widgets/timeline_desktop.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/services/dashboard_cache_service.dart';
import 'package:trial1/services/sync_event_service.dart';
import 'package:trial1/models/dashboard_models.dart';
import 'package:trial1/models/sync_ui_state.dart';
import 'package:trial1/widgets/academic_item_card.dart';

class HomeScreen extends StatefulWidget {
  final int oauthRefreshToken;

  const HomeScreen({super.key, this.oauthRefreshToken = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _DashboardSnapshot {
  final Map<String, dynamic> raw;

  const _DashboardSnapshot({required this.raw});
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _fallbackPollInterval = Duration(seconds: 60);
  static const double _desktopContentBreakpoint = 900;
  static const double _timelinePanelWidth = 280;
  static const double _focusCollapseThreshold = 160;

  static const List<({String label, String key})> _fixedCategories = [
    (label: 'Assignments', key: 'ASSIGNMENT'),
    (label: 'Exams', key: 'EXAM'),
    (label: 'Opportunities', key: 'OPPORTUNITY'),
    (label: 'Announcements', key: 'ACADEMIC_ADMIN'),
  ];

  late Future<Map<String, dynamic>> _profileFuture;
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
  final Set<int> _optimisticItemUpdates = <int>{};
  String? _dashboardError;
  SyncUIState? _syncUiState;
  int _aiPendingCount = 0; // Track AI processing progress
  String _activeTabKey = 'ASSIGNMENT';
  final ScrollController _taskScrollController = ScrollController();
  bool _showCompactFocus = false;
  bool? _oauthConnected;

  @override
  void initState() {
    super.initState();
    _taskScrollController.addListener(_handleTaskScroll);
    _profileFuture = BackendService.fetchUserProfile();
    _profileFuture
        .then((profile) {
          if (!mounted) return;
          final connected = _isOauthConnected(profile);
          setState(() {
            _oauthConnected = connected;
          });
          if (connected) {
            unawaited(_bootstrapDashboard());
          } else {
            unawaited(_resetDashboardState(clearCache: true));
          }
        })
        .catchError((_) {
          // The FutureBuilder below renders the actual profile error state.
        });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.oauthRefreshToken == oldWidget.oauthRefreshToken) {
      return;
    }

    _profileFuture = BackendService.fetchUserProfile();
    if (mounted) {
      setState(() {
        _syncUiState = SyncUIState.preparing();
        _dashboardLoading = true;
        _dashboardError = null;
      });
    }
    _profileFuture.then((profile) {
      if (!mounted) return;
      final connected = _isOauthConnected(profile);
      setState(() {
        _oauthConnected = connected;
      });
      if (connected) {
        unawaited(_bootstrapDashboard());
      } else {
        unawaited(_resetDashboardState(clearCache: true));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sseSubscription?.cancel();
    _taskScrollController.removeListener(_handleTaskScroll);
    _taskScrollController.dispose();
    _dashboardSnapshot.dispose();
    super.dispose();
  }

  void _handleTaskScroll() {
    final shouldShowCompactFocus =
        _taskScrollController.hasClients &&
        _taskScrollController.offset > _focusCollapseThreshold;
    if (shouldShowCompactFocus == _showCompactFocus) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _showCompactFocus = shouldShowCompactFocus;
    });
  }

  bool _isOauthConnected(Map<String, dynamic> profile) {
    return profile['oauth_connected'] == true ||
        profile['oauth_connected'] == 1;
  }

  Future<void> _resetDashboardState({bool clearCache = false}) async {
    _stopPolling();
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseHealthy = false;
    _sseReconnectScheduled = false;
    _refreshInFlight = false;
    _lastFingerprint = null;
    _aiPendingCount = 0;
    _syncUiState = null;
    _dashboardSnapshot.value = null;
    if (clearCache) {
      await DashboardCacheService.clearSnapshot();
    }
    if (!mounted) return;
    setState(() {
      _dashboardLoading = false;
      _dashboardError = null;
    });
  }

  List<({String label, String key})> _dashboardCategories(
    UnifiedDashboardData data,
  ) {
    final categories = <({String label, String key})>[];
    final seen = <String>{};

    for (final category in _fixedCategories) {
      categories.add(category);
      seen.add(category.key);
    }

    final extraKeys = data.grouped.keys
        .where((key) => !seen.contains(key))
        .toList()
      ..sort();

    for (final key in extraKeys) {
      categories.add((label: _humanizeCategoryKey(key), key: key));
    }

    return categories;
  }

  String _humanizeCategoryKey(String key) {
    return key
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
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
        if (event.isEmpty) {
          return;
        }

        _sseHealthy = true;
        _stopPolling();

        final eventType = event['type']?.toString();
        if (eventType == 'item_updated') {
          final rawItemId = event['item_id'];
          final itemId = rawItemId is int
              ? rawItemId
              : int.tryParse(rawItemId?.toString() ?? '');
          if (itemId != null && _optimisticItemUpdates.contains(itemId)) {
            return;
          }
          unawaited(_refreshDashboard(force: true, updateLoadingState: false));
          return;
        }

        final status = event['status']?.toString();
        final pipelineComplete = event['pipeline_complete'] == true;
        final rawAiPending = event['ai_pending_count'];
        final aiPendingCount = rawAiPending is int
            ? rawAiPending
            : (int.tryParse(rawAiPending?.toString() ?? '') ?? 0);

        final nextSyncState = SyncUIState.fromSyncEvent(
          event,
          previous: _syncUiState,
        );

        if (mounted) {
          setState(() {
            _syncUiState = nextSyncState;
            _aiPendingCount = aiPendingCount;
          });
        } else {
          _aiPendingCount = aiPendingCount;
        }

        // Only refresh dashboard when pipeline is truly complete
        if (pipelineComplete) {
          unawaited(_refreshDashboard(force: true, updateLoadingState: false));
        } else if ((status == 'completed' || status == 'no_action') &&
            aiPendingCount > 0) {
          // Sync done, but AI processing still ongoing
        } else if (status == 'failed') {
          unawaited(_refreshDashboard(force: true, updateLoadingState: false));
        }
      },
      onError: (_) {
        _sseHealthy = false;
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
    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
      _syncUiState = SyncUIState.preparing();
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

      _startSseWatcher(uid);

      if (syncStatus == 'in_progress') {
        return;
      } else {
        await BackendService.triggerIncrementalSync(uid);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      final failureDetail = e is SyncStreamUnavailableException
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
    if (_refreshInFlight) {
      return false;
    }

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

  Map<String, dynamic>? _applyOptimisticItemRemoval(int itemId) {
    final current = _dashboardSnapshot.value;
    if (current == null) {
      return null;
    }

    final previous =
        jsonDecode(jsonEncode(current.raw)) as Map<String, dynamic>;
    final next = jsonDecode(jsonEncode(current.raw)) as Map<String, dynamic>;

    bool removeById(dynamic rawItem) {
      if (rawItem is Map<String, dynamic>) {
        final rawId = rawItem['id'];
        if (rawId is int) return rawId == itemId;
        return rawId?.toString() == itemId.toString();
      }
      return false;
    }

    final focus = next['focus'];
    if (focus is Map<String, dynamic> && removeById(focus)) {
      next['focus'] = null;
    } else if (focus is List) {
      focus.removeWhere((entry) => removeById(entry));
      next['focus'] = focus;
    }

    final groups = next['groups'];
    if (groups is Map<String, dynamic>) {
      for (final key in groups.keys.toList()) {
        final entries = groups[key];
        if (entries is List) {
          entries.removeWhere((entry) => removeById(entry));
          groups[key] = entries;
        }
      }
    }

    final academicItems = next['academic_items'];
    if (academicItems is List) {
      academicItems.removeWhere((entry) => removeById(entry));
      next['academic_items'] = academicItems;
    }

    final timeline = next['timeline'];
    if (timeline is List) {
      for (final group in timeline.whereType<Map<String, dynamic>>()) {
        final items = group['items'];
        if (items is List) {
          items.removeWhere((entry) {
            if (entry is! Map<String, dynamic>) return false;
            final rawId = entry['id']?.toString() ?? '';
            return rawId == 'item-$itemId' || rawId == itemId.toString();
          });
          group['items'] = items;
        }
      }
    }

    _lastFingerprint = _dashboardFingerprint(next);
    _dashboardSnapshot.value = _DashboardSnapshot(raw: next);
    unawaited(DashboardCacheService.saveSnapshot(next));

    return previous;
  }

  Future<void> _runOptimisticItemAction({
    required AcademicItem item,
    required Future<void> Function(int itemId) action,
    required String successMessage,
  }) async {
    final previous = _applyOptimisticItemRemoval(item.id);
    _optimisticItemUpdates.add(item.id);

    try {
      await action(item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (previous != null) {
        _lastFingerprint = _dashboardFingerprint(previous);
        _dashboardSnapshot.value = _DashboardSnapshot(raw: previous);
        await DashboardCacheService.saveSnapshot(previous);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    } finally {
      _optimisticItemUpdates.remove(item.id);
      unawaited(_refreshDashboard(force: true, updateLoadingState: false));
    }
  }

  Future<void> _markDoneOptimistic(AcademicItem item) {
    return _runOptimisticItemAction(
      item: item,
      action: BackendService.markAcademicItemDone,
      successMessage: 'Marked as completed',
    );
  }

  Future<void> _dismissOptimistic(AcademicItem item) {
    return _runOptimisticItemAction(
      item: item,
      action: BackendService.dismissAcademicItem,
      successMessage: 'Dismissed',
    );
  }

  Future<void> _calendarOptimistic(AcademicItem item) {
    return _runOptimisticItemAction(
      item: item,
      action: BackendService.addAcademicItemToCalendar,
      successMessage: 'Added to calendar',
    );
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
              color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              loadingContainer,
              const SizedBox(height: 14),
              const FocusCard(),
              const SizedBox(height: 14),
              _buildChipsHeader(
                context,
                UnifiedDashboardData(
                  focus: const [],
                  grouped: const {},
                  timelineItems: const [],
                  timelineGroups: const [],
                ),
              ),
              const SizedBox(height: 14),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  loadingContainer,
                  const SizedBox(height: 14),
                  const FocusCard(),
                  const SizedBox(height: 14),
                  _buildChipsHeader(
                    context,
                    UnifiedDashboardData(
                      focus: const [],
                      grouped: const {},
                      timelineItems: const [],
                      timelineGroups: const [],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: _timelinePanelWidth,
              child: _buildTimelinePanel(const []),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiProcessingState(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final pendingLabel = _aiPendingCount == 1
        ? '1 email left'
        : '$_aiPendingCount emails left';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        final processingContainer = Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.64),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      color: accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Working our magic',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'We are turning your inbox into a clean academic dashboard.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.72,
                            ),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.7),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_outlined, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      pendingLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildPreparationStep(
                context,
                icon: Icons.mark_email_read_outlined,
                text: 'Reading academic signals from your latest emails',
              ),
              const SizedBox(height: 10),
              _buildPreparationStep(
                context,
                icon: Icons.rule_folder_outlined,
                text: 'Finding deadlines, tasks, announcements, and events',
              ),
              const SizedBox(height: 10),
              _buildPreparationStep(
                context,
                icon: Icons.dashboard_customize_outlined,
                text: 'Arranging everything into your dashboard',
              ),
              const SizedBox(height: 18),
              Text(
                'You can switch tabs or come back in a bit. We will keep preparing this in the background.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
                  height: 1.35,
                ),
              ),
            ],
          ),
        );

        if (isMobile) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: processingContainer,
          );
        }

        return Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: processingContainer,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncBootstrapState(BuildContext context, SyncUIState state) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isProblem =
        state.phase == SyncUIPhase.failed || state.phase == SyncUIPhase.timeout;
    final icon = state.phase == SyncUIPhase.ready
        ? Icons.check_rounded
        : isProblem
        ? Icons.refresh_rounded
        : Icons.cloud_sync_outlined;

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer.withValues(
                  alpha: 0.64,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (isProblem ? theme.colorScheme.error : accent)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: isProblem ? theme.colorScheme.error : accent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              state.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.72,
                                ),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: state.progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: isProblem ? 0 : value.clamp(0.0, 1.0),
                          backgroundColor: theme
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.7),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isProblem ? theme.colorScheme.error : accent,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.58,
                      ),
                      height: 1.35,
                    ),
                  ),
                  if (!state.isActive) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: () {
                          unawaited(_bootstrapDashboard());
                        },
                        child: const Text('Retry sync'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreparationStep(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              height: 1.35,
            ),
          ),
        ),
      ],
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

  Widget _buildChipsHeader(
    BuildContext context,
    UnifiedDashboardData data,
  ) {
    final categories = _dashboardCategories(data);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const SizedBox(width: 2),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _FilterChipPill(
                  label: category.label,
                  selected: _activeTabKey == category.key,
                  onTap: () => setState(() => _activeTabKey = category.key),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: _FilterChipPill(
                label: '+',
                selected: false,
                onTap: () => _showManualTaskComposer(context, categories),
                icon: Icons.add_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelinePanel(List<Map<String, dynamic>> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: TimelineDesktop(
              groups: groups,
              onItemTap: null, // passive
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactFocusCard(AcademicItem item) {
    final meta = academicCategoryMeta(item.entityType);
    final due = item.dueDate ?? item.eventDate;
    final summary = (item.aiSummary?.trim().isNotEmpty ?? false)
        ? item.aiSummary!
        : item.description;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: meta.color.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${topicLabel(item.aiLabelTopic ?? item.entityType).toUpperCase()} • ${_shortDeadlineLabel(due)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _markDoneOptimistic(item),
                  child: const Text('Done'),
                ),
                OutlinedButton(
                  onPressed: () => _dismissOptimistic(item),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortDeadlineLabel(DateTime? date) {
    if (date == null) return 'No deadline';
    final now = DateTime.now();
    final diff = date.difference(now);
    if (diff.isNegative) return 'Overdue';
    if (diff.inDays == 0) return 'Due today';
    if (diff.inDays == 1) return 'Due tomorrow';
    if (diff.inDays < 7) return 'Due in ${diff.inDays}d';
    return DateFormat.MMMd().format(date);
  }

  void _showManualTaskComposer(
    BuildContext context,
    List<({String label, String key})> categories,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _ManualTaskComposerSheet(
        categories: categories,
        onSaved: () => _refreshDashboard(force: true),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    UnifiedDashboardData data,
  ) {
    final focusItem = data.focus.isNotEmpty ? data.focus.first : null;

    final selectedBucketItems =
        data.grouped[_activeTabKey] ?? const <AcademicItem>[];
    final items = selectedBucketItems;

    Widget buildItemsList() {
      if (items.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: true,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You are all caught up',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No ${_humanizeCategoryKey(_activeTabKey).toLowerCase()} right now.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) {
                return const SizedBox(height: 10);
              }

              final item = items[index ~/ 2];
              return AcademicItemCard(
                item: item,
                onTap: () {},
                previewOnTap: true,
                hideLabel: true,
                onActionCompleted: () async {
                  await _refreshDashboard(force: true, updateLoadingState: false);
                },
                onMarkDoneAction: _markDoneOptimistic,
                onAddToCalendarAction: _calendarOptimistic,
                onDismissAction: _dismissOptimistic,
              );
            },
            childCount: items.isEmpty ? 0 : items.length * 2 - 1,
          ),
        ),
      );
    }

    final leftScrollView = CustomScrollView(
      controller: _taskScrollController,
      slivers: [
        if (focusItem != null)
          SliverToBoxAdapter(
            child: FocusCard(
              item: focusItem,
              onActionCompleted: () => unawaited(_refreshDashboard(force: true)),
              onActionDismissed: () => unawaited(_refreshDashboard(force: true)),
              onMarkDoneAction: _markDoneOptimistic,
              onDismissAction: _dismissOptimistic,
            ),
          ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyHeaderDelegate(
            child: _buildChipsHeader(context, data),
          ),
        ),
        buildItemsList(),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _desktopContentBreakpoint;

        if (isMobile) {
          return CustomScrollView(
            controller: _taskScrollController,
            slivers: [
              if (focusItem != null)
                SliverToBoxAdapter(
                  child: FocusCard(
                    item: focusItem,
                    onActionCompleted: () => unawaited(_refreshDashboard(force: true)),
                    onActionDismissed: () => unawaited(_refreshDashboard(force: true)),
                    onMarkDoneAction: _markDoneOptimistic,
                    onDismissAction: _dismissOptimistic,
                  ),
                ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyHeaderDelegate(
                  child: _buildChipsHeader(context, data),
                ),
              ),
              buildItemsList(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: SizedBox(
                    height: 220,
                    child: SingleChildScrollView(
                      child: TimelineSection(
                        groups: data.timelineGroups,
                        onItemTap: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: leftScrollView,
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: _timelinePanelWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (focusItem != null && _showCompactFocus) ...[
                    _buildCompactFocusCard(focusItem),
                    const SizedBox(height: 14),
                  ],
                  Expanded(child: _buildTimelinePanel(data.timelineGroups)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCreateAction = _oauthConnected == true;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Notify Sphere',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.03,
                  ),
            ),
            const SizedBox(height: 2),
          ],
        ),
        actions: [
          if (showCreateAction)
            IconButton(
              tooltip: 'New task',
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => _showManualTaskComposer(context, _fixedCategories),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person_rounded),
              onPressed: () async {
                final disconnected = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
                if (!mounted) return;
                if (disconnected == true) {
                  setState(() {
                    _oauthConnected = false;
                  });
                  await _resetDashboardState(clearCache: true);
                }
                setState(() {
                  _profileFuture = BackendService.fetchUserProfile();
                });
                _profileFuture.then((profile) {
                  if (!mounted) return;
                  final connected = _isOauthConnected(profile);
                  setState(() {
                    _oauthConnected = connected;
                  });
                  if (connected) {
                    unawaited(_bootstrapDashboard());
                  } else {
                    unawaited(_resetDashboardState(clearCache: true));
                  }
                });
              },
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

          return ValueListenableBuilder<_DashboardSnapshot?>(
            valueListenable: _dashboardSnapshot,
            builder: (context, dashboardSnapshot, _) {
              return FutureBuilder<Map<String, dynamic>>(
                future: _profileFuture,
                builder: (context, profileSnapshot) {
                  if (profileSnapshot.connectionState !=
                      ConnectionState.done) {
                    if (_syncUiState != null || widget.oauthRefreshToken > 0) {
                      return _buildSyncBootstrapState(
                        context,
                        _syncUiState ?? SyncUIState.preparing(),
                      );
                    }
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
                    if (_syncUiState != null || widget.oauthRefreshToken > 0) {
                      return _buildSyncBootstrapState(
                        context,
                        _syncUiState ?? SyncUIState.preparing(),
                      );
                    }
                    return const ConnectGmailScreen(
                      allowSkip: false,
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16.0,
                    ),
                    child: Builder(
                      builder: (context) {
                        final syncState = _syncUiState;
                        if (syncState?.isActive == true) {
                          return _buildSyncBootstrapState(context, syncState!);
                        }

                        if (_dashboardError != null && dashboardSnapshot == null) {
                          return SingleChildScrollView(
                            child: _buildDashboardError(
                              context,
                              _dashboardError!,
                            ),
                          );
                        }

                        if (syncState != null && dashboardSnapshot == null) {
                          return _buildSyncBootstrapState(context, syncState);
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
                        final hasDisplayableItems = data.grouped.values.any(
                          (items) => items.isNotEmpty,
                        );
                        if (_aiPendingCount > 0 && !hasDisplayableItems) {
                          return _buildAiProcessingState(context);
                        }

                        return _buildDashboardContent(context, data);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ManualTaskComposerSheet extends StatefulWidget {
  final List<({String label, String key})> categories;
  final Future<void> Function() onSaved;

  const _ManualTaskComposerSheet({
    required this.categories,
    required this.onSaved,
  });

  @override
  State<_ManualTaskComposerSheet> createState() => _ManualTaskComposerSheetState();
}

class _ManualTaskComposerSheetState extends State<_ManualTaskComposerSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;
  DateTime? _dueDate;
  late String _selectedCategory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _detailsController = TextEditingController();
    _selectedCategory = widget.categories.isNotEmpty
        ? widget.categories.first.key
        : _HomeScreenState._fixedCategories.first.key;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _dueDate ?? DateTime.now(),
    );
    if (!mounted || picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final details = _detailsController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title first')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await BackendService.createManualAcademicEntity(
        canonicalTitle: title,
        entityType: _selectedCategory,
        summary: details.isEmpty ? null : details,
        bestDeadline: _dueDate,
      );
      if (!mounted) return;
      await widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $title')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save draft: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual task',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a draft task without leaving the dashboard.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detailsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category.key,
                      child: Text(category.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedCategory = value);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDueDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _dueDate == null
                    ? 'Pick due date'
                    : DateFormat.yMMMd().format(_dueDate!),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save draft'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 74;

  @override
  double get maxExtent => 74;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _FilterChipPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.primary.withValues(alpha: 0.12) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.7),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
