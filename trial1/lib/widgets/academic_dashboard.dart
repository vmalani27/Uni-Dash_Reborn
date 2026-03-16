import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/models/academic_event.dart';
import 'package:trial1/services/gmail_sync_service.dart';
import 'package:trial1/services/event_mapper.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/academic_event_card.dart';
import 'package:trial1/widgets/skeleton_loader.dart';
import 'package:trial1/theme.dart';
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

class _AcademicDashboardState extends State<AcademicDashboard> with WidgetsBindingObserver {
  bool _loading = true;
  String? _error;
  List<AcademicEvent> _events = [];
  Map<AcademicEventType, List<AcademicEvent>> _groupedEvents = {};

  late ScrollController _scrollController;
  Timer? _autoRefreshTimer;
  late RefreshController _refreshController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _refreshController = RefreshController();
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
      final result = await GmailSyncService.loadNotificationsInstant();
      if (!mounted) return;

      final events = mapNotificationsToEvents(result);
      setState(() {
        _events = events;
        _groupedEvents = groupEventsByType(events);
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
      final result = await GmailSyncService.loadNotificationsInstant();
      final events = mapNotificationsToEvents(result);

      if (mounted) {
        setState(() {
          _events = events;
          _groupedEvents = groupEventsByType(events);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load events. Please try again.';
          _loading = false;
        });
      }
    } finally {
      _refreshController.refreshComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading && _events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 0),
        child: SkeletonNotificationList(),
      );
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    if (_events.isEmpty) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Summary stats
          _buildSummaryBar(context),
          const SizedBox(height: 16),

          // Events grouped by type
          ...typeDisplayOrder
              .where((type) => _groupedEvents.containsKey(type) && _groupedEvents[type]!.isNotEmpty)
              .map((type) => _buildTypeSection(context, type, _groupedEvents[type]!))
              .expand((widget) => [widget, const SizedBox(height: 16)]),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final critical = _events.where((e) => e.urgency == 'Critical').length;
    final total = _events.length;
    final activeCount = _events.where((e) => e.isActive).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            label: 'Total',
            value: total.toString(),
            color: colorScheme.onSurface,
          ),
          _SummaryItem(
            label: 'Active',
            value: activeCount.toString(),
            color: colorScheme.primary,
          ),
          _SummaryItem(
            label: 'Critical',
            value: critical.toString(),
            color: kUrgencyCritical,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSection(BuildContext context, AcademicEventType type, List<AcademicEvent> events) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type header
        Text(
          _typeLabel(type),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),

        // Events for this type
        ...events.map((event) => AcademicEventCard(
          event: event,
          onTap: () => _navigateToDetail(event),
        )),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kUrgencyCritical.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: kUrgencyCritical.withOpacity(0.7),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadEvents,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No events yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New academic emails will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(AcademicEvent event) {
    // TODO: Navigate to email detail view with event.sourceEmailId
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: ${event.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _typeLabel(AcademicEventType type) {
    switch (type) {
      case AcademicEventType.assignment:
        return '📝 Assignments';
      case AcademicEventType.exam:
        return '🧪 Exams';
      case AcademicEventType.academic:
        return '🎓 Academic';
      case AcademicEventType.opportunity:
        return '🚀 Opportunities';
      case AcademicEventType.information:
        return 'ℹ️ Information';
      case AcademicEventType.other:
        return '📧 Other';
    }
  }
}

/// Summary stat display (label + value).
class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

/// Refresh controller stub for pull-to-refresh pattern (can use real_pull_to_refresh pkg).
class RefreshController {
  void refreshComplete() {}
}
