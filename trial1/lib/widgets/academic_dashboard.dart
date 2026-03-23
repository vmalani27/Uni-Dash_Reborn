import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/models/dashboard_models.dart';
import 'package:trial1/services/gmail_sync_service.dart';
import 'package:trial1/widgets/dashboard/focus_section.dart';
import 'package:trial1/widgets/dashboard/category_scroll_section.dart';
import 'package:trial1/widgets/dashboard/timeline_section.dart';
import 'package:trial1/widgets/dashboard/ai_inbox_section.dart';
import 'package:trial1/widgets/skeleton_loader.dart';
import 'dart:async';

/// Academic Dashboard — organized event view.
///
/// Displays AcademicEvents grouped by type, sorted by urgency + academic score.
/// - Loads data on init
/// - Auto-refreshes every 30s while foregrounded
/// - Pull-to-refresh for manual refresh
///
/// This is intended to replace the list-based GmailNotificationsList for
/// a higher-level dashboard experience.
class AcademicDashboard extends StatefulWidget {
  const AcademicDashboard({super.key});

  @override
  State<AcademicDashboard> createState() => _AcademicDashboardState();
}

class _AcademicDashboardState extends State<AcademicDashboard>
    with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  UnifiedDashboardData? _dashboardData;
  int _selectedViewIndex = 0; // 0: Dashboard, 1: AI Inbox

  late ScrollController _scrollController;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _loadEvents();
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
      _loadEvents();
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused) {
      _autoRefreshTimer?.cancel();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _silentRefresh() async {
    try {
      final data = await GmailSyncService.loadDashboard();
      if (!mounted) return;

      setState(() {
        _dashboardData = UnifiedDashboardData.fromJson(data);
      });
    } catch (e) {
      // Silent fail on background refresh
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await GmailSyncService.loadDashboard();
      if (mounted) {
        setState(() {
          _dashboardData = UnifiedDashboardData.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading && _dashboardData == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 0),
        child: SkeletonNotificationList(),
      );
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    if (_dashboardData == null ||
        (_dashboardData!.focus.isEmpty && _dashboardData!.grouped.isEmpty)) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        _buildViewSelector(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadEvents,
            color: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            child: _selectedViewIndex == 0
                ? _buildMainDashboard(context)
                : _buildAiInbox(context),
          ),
        ),
      ],
    );
  }

  Widget _buildViewSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Dashboard'),
            icon: Icon(Icons.dashboard_outlined),
          ),
          ButtonSegment(
            value: 1,
            label: Text('AI Inbox'),
            icon: Icon(Icons.auto_awesome_outlined),
          ),
        ],
        selected: {_selectedViewIndex},
        onSelectionChanged: (value) {
          setState(() {
            _selectedViewIndex = value.first;
          });
        },
        showSelectedIcon: false,
      ),
    );
  }

  Widget _buildMainDashboard(BuildContext context) {
    final data = _dashboardData!;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: [
        // Smart banner from backend
        if (data.banner != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
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
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      data.banner!['message'] ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('View')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // 1. Focus Section
        FocusSection(items: data.focus, onItemTap: _navigateToItemDetail),
        const SizedBox(height: 24),

        // 2. Categories Scroll
        CategoryScrollSection(
          title: 'Assignments',
          items: data.grouped['ASSIGNMENT'] ?? [],
          onItemTap: _navigateToItemDetail,
        ),
        const SizedBox(height: 16),
        CategoryScrollSection(
          title: 'Exams',
          items: data.grouped['EXAM'] ?? [],
          onItemTap: _navigateToItemDetail,
        ),
        const SizedBox(height: 16),
        CategoryScrollSection(
          title: 'Opportunities',
          items: data.grouped['OPPORTUNITY'] ?? [],
          onItemTap: _navigateToItemDetail,
        ),
        const SizedBox(height: 24),

        // 3. Timeline (render backend-provided groups)
        TimelineSection(
          groups: data.timelineGroups,
          onItemTap: _navigateToItemDetail,
        ),
      ],
    );
  }

  Widget _buildAiInbox(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 32.0),
        child: AiInboxSection(messages: []),
      ),
    );
  }

  void _navigateToItemDetail(dynamic raw) {
    AcademicItem item;
    if (raw is AcademicItem) {
      item = raw;
    } else if (raw is Map<String, dynamic>) {
      DateTime? due;
      if (raw['time'] != null) {
        try {
          due = DateTime.parse(raw['time'] as String).toLocal();
        } catch (_) {
          due = null;
        }
      }
      item = AcademicItem(
        id: raw['id'] is int
            ? raw['id'] as int
            : int.tryParse('${raw['id']}') ?? 0,
        sourceEmailId: raw['source_email_id'] as String? ?? '',
        entityType:
            raw['type'] as String? ??
            raw['entity_type'] as String? ??
            'INFORMATION',
        title: raw['title'] as String? ?? 'Untitled',
        description: raw['description'] as String? ?? '',
        dueDate: due,
        location: raw['location'] as String?,
        courseCode: raw['course_code'] as String?,
        professor: raw['professor'] as String?,
        academicScore: (raw['academic_score'] as num?)?.toDouble() ?? 0.0,
        completed: raw['completed'] as bool? ?? false,
      );
    } else {
      return;
    }
    // TODO: Reuse existing detail navigation logic if applicable
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Focusing on: ${item.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadEvents, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('No items found'),
        ],
      ),
    );
  }
}
