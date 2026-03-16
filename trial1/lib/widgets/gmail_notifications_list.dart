import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/services/gmail_sync_service.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/notification_tile.dart';
import 'package:trial1/widgets/topic_section.dart';
import 'package:trial1/widgets/classification_banner.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/skeleton_loader.dart';
import 'dart:async';

/// Gmail Notifications Dashboard
///
/// Pure state viewer. No sync triggers, no classification triggers.
/// - Loads data on init
/// - Auto-refreshes every 30s while foregrounded
/// - Pull-to-refresh for manual refresh
class GmailNotificationsList extends StatefulWidget {
  const GmailNotificationsList({super.key});

  @override
  State<GmailNotificationsList> createState() => _GmailNotificationsListState();
}

class _GmailNotificationsListState extends State<GmailNotificationsList>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<GmailNotificationPreview> _allNotifications = [];

  // Pagination
  final int _pageSize = 20;
  int _currentOffset = 0;
  bool _hasMoreData = true;

  // View toggle
  bool _isOrganizedView = false;
  int _unprocessedCount = 0;
  bool _isFirstSync = false; // True when initial sync is in progress

  late ScrollController _scrollController;
  Timer? _autoRefreshTimer;

  // Topic ordering for organized view
  static const _topicOrder = [
    'ASSIGNMENT',
    'EXAM',
    'ACADEMIC_ADMIN',
    'OPPORTUNITY',
    'INFORMATION',
    'UNCLASSIFIED',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadNotifications();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — refresh and restart timer
      _loadNotifications();
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused) {
      // App went to background — stop timer
      _autoRefreshTimer?.cancel();
    }
  }

  // ─── Auto-refresh ───────────────────────────────────────────

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentRefresh(),
    );
  }

  /// Refresh data without showing loading state
  Future<void> _silentRefresh() async {
    try {
      final result = await GmailSyncService.loadNotificationsInstant();
      if (!mounted) return;

      final unprocessed = result.notifications
          .where((n) => n.normalizedTopic == 'OTHER' && n.academicScore == 0)
          .length;

      // Only update if data actually changed
      if (result.notifications.length != _allNotifications.length) {
        setState(() {
          _allNotifications = result.notifications;
          _currentOffset = result.notifications.length;
          _hasMoreData = result.notifications.length >= _pageSize;
          _unprocessedCount = unprocessed;
          _isOrganizedView =
              unprocessed < result.notifications.length &&
              result.notifications.isNotEmpty;
        });
      }
    } catch (_) {
      // Silent failure — don't disrupt the UI
    }
  }

  // ─── Data fetching ──────────────────────────────────────────

  void _onScroll() {
    final pixels = _scrollController.position.pixels;
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (pixels >= maxExtent - 200 && !_loadingMore && _hasMoreData) {
      _loadMoreNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
      _allNotifications = [];
      _currentOffset = 0;
      _hasMoreData = true;
    });
    try {
      final result = await GmailSyncService.loadNotificationsInstant();
      final unprocessed = result.notifications
          .where((n) => n.normalizedTopic == 'OTHER' && n.academicScore == 0)
          .length;

      // Detect first-time sync: 0 emails but user may have just connected
      bool firstSync = false;
      if (result.notifications.isEmpty) {
        try {
          final uid = await BackendService.getCurrentUid();
          final syncStatus = await BackendService.fetchGmailSyncStatus(uid);
          firstSync = syncStatus == 'in_progress' || syncStatus == 'no_status';
        } catch (_) {
          // If sync status check fails, assume not first sync
        }
      }

      setState(() {
        _allNotifications = result.notifications;
        _currentOffset = result.notifications.length;
        _hasMoreData = result.notifications.length >= _pageSize;
        _unprocessedCount = unprocessed;
        _isFirstSync = firstSync;
        _isOrganizedView =
            unprocessed < result.notifications.length &&
            result.notifications.isNotEmpty;
      });

      // If first sync, refresh faster to pick up incoming emails
      if (firstSync) {
        _autoRefreshTimer?.cancel();
        _autoRefreshTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => _silentRefresh(),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_loadingMore || !_hasMoreData) return;
    setState(() => _loadingMore = true);

    try {
      final response = await BackendService.fetchGmailNotifications(
        offset: _currentOffset,
        limit: _pageSize,
      );
      final newNotifications = response
          .map(
            (n) => GmailNotificationPreview.fromJson(n as Map<String, dynamic>),
          )
          .toList();

      setState(() {
        _allNotifications.addAll(newNotifications);
        _currentOffset += newNotifications.length;
        _hasMoreData = newNotifications.length >= _pageSize;
      });
    } catch (e) {
      print('[Pagination] Error: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_loading && _allNotifications.isEmpty) {
      return const SkeletonNotificationList();
    }

    // Error state
    if (_error != null && _allNotifications.isEmpty) {
      return _buildErrorState();
    }

    // Empty state
    if (_allNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Processing status + view toggle
          SliverToBoxAdapter(
            child: ClassificationBanner(
              unprocessedCount: _unprocessedCount,
              isOrganizedView: _isOrganizedView,
              totalNotifications: _allNotifications.length,
              onViewToggle: (value) => setState(() => _isOrganizedView = value),
            ),
          ),

          // ─ ORGANIZED VIEW ─
          if (_isOrganizedView)
            ..._topicOrder.map((topic) {
              final items = _allNotifications
                  .where((n) => n.normalizedTopic == topic)
                  .toList();
              return TopicSection(normalizedTopic: topic, notifications: items);
            })
          // ─ CHRONOLOGICAL VIEW ─
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= _allNotifications.length) {
                  return const SizedBox.shrink();
                }
                return NotificationTile(notification: _allNotifications[index]);
              }, childCount: _allNotifications.length),
            ),

          // Loading more indicator
          if (_loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
              ),
            ),

          // End of list
          if (!_hasMoreData && _allNotifications.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'You\'re all caught up',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // ─── State Widgets ──────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kUrgencyCritical.withOpacity(0.1), // keep as is, theme constant
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: kUrgencyCritical.withOpacity(0.7), // keep as is, theme constant
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Couldn\'t load emails',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // ─ First-time sync in progress ─
    if (_isFirstSync) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Setting things up…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Syncing your emails for the first time.\nThis may take a minute.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ─ Genuinely empty ─
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up!',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'No notifications yet. Emails are synced automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
