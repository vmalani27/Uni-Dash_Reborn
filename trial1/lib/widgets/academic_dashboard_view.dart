import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/models/dashboard_models.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/academic_item_card.dart';
import 'package:trial1/widgets/skeleton_loader.dart';

class AcademicDashboardView extends StatefulWidget {
  final String? initialFilter;

  const AcademicDashboardView({super.key, this.initialFilter});

  @override
  State<AcademicDashboardView> createState() => _AcademicDashboardViewState();
}

class _AcademicDashboardViewState extends State<AcademicDashboardView> {
  List<AcademicItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await BackendService.fetchUnifiedDashboard();
      final parsed = UnifiedDashboardData.fromJson(data);
      // flatten grouped lists into a simple list for this view (preserve backend ordering)
      final flattened = <AcademicItem>[];
      for (final key in [
        'ASSIGNMENT',
        'EXAM',
        'ACADEMIC_ADMIN',
        'OPPORTUNITY',
        'INFORMATION',
      ]) {
        flattened.addAll(parsed.grouped[key] ?? []);
      }

      // Apply initial filter if provided (map display label -> group key)
      if (widget.initialFilter != null) {
        final labelToKey = {
          'Assignments': 'ASSIGNMENT',
          'Exams': 'EXAM',
          'Opportunities': 'OPPORTUNITY',
          'Announcements': 'ACADEMIC_ADMIN',
        };
        final key = labelToKey[widget.initialFilter!];
        if (key != null) {
          flattened.retainWhere(
            (it) => (it.entityType ?? 'INFORMATION') == key,
          );
        }
      }
      if (mounted) {
        setState(() {
          _items = flattened;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const SkeletonNotificationList();
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDashboard,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: _items.isEmpty
          ? _buildEmptyState()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return AcademicItemCard(
                      item: item,
                      onActionCompleted: _fetchDashboard,
                      onTap: () async {
                        final res = await Navigator.of(
                          context,
                        ).pushNamed('/item', arguments: item);
                        if (res == true) {
                          // Action performed in details screen; refresh dashboard
                          _fetchDashboard();
                        }
                      },
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'You\'re all caught up!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'No pending assignments or exams.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Navigation to full-screen details is handled by the onTap callback above.
}
