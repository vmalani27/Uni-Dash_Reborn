import 'package:flutter/material.dart';
import 'package:trial1/widgets/focus_card.dart';
import 'package:trial1/widgets/dashboard/category_overview.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/dashboard/vertical_sections.dart';
import 'package:trial1/widgets/dashboard/timeline_section.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/models/dashboard_models.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? themeToggle;
  final ThemeMode? themeMode;

  const HomeScreen({super.key, this.themeToggle, this.themeMode});

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = 1100.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UniDash'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: themeToggle,
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
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: FutureBuilder<Map<String, dynamic>>(
                future: BackendService.fetchUnifiedDashboard(),
                builder: (context, snapshot) {
                  // Loading state
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // banner placeholder
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16.0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(
                                  context,
                                ).snackBarTheme.backgroundColor ??
                                Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Loading dashboard...',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Focus placeholder
                        const FocusCard(),

                        const SizedBox(height: 20),

                        // Sections placeholder (empty)
                        VerticalSections(groups: {}),

                        const SizedBox(height: 20),

                        // Timeline placeholder
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TimelineSection(groups: [], onItemTap: (_) {}),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
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
                            Text(snapshot.error.toString()),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () =>
                                  (context as Element).reassemble(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Data ready: use unified dashboard from backend
                  final json = snapshot.data ?? {};
                  final data = UnifiedDashboardData.fromJson(json);

                  // Determine a single nextAction across all groups (highest academicScore)
                  final allItems = <AcademicItem>[];
                  data.grouped.forEach((k, v) => allItems.addAll(v));

                  AcademicItem? nextActionItem;
                  if (allItems.isNotEmpty) {
                    allItems.sort(
                      (a, b) => b.academicScore.compareTo(a.academicScore),
                    );
                    nextActionItem = allItems.first;
                  }

                  // Single Focus
                  final focusWidget = FocusCard(item: nextActionItem);

                  // Category overview counts
                  final counts = {
                    'Assignments': data.grouped['ASSIGNMENT']?.length ?? 0,
                    'Exams': data.grouped['EXAM']?.length ?? 0,
                    'Opportunities': data.grouped['OPPORTUNITY']?.length ?? 0,
                    'Announcements':
                        data.grouped['ACADEMIC_ADMIN']?.length ?? 0,
                  };

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      focusWidget,
                      const SizedBox(height: 20),

                      // Category overview (collapsed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: CategoryOverview(
                          counts: counts,
                          onSelect: (label) {
                            Navigator.of(context).pushNamed(
                              '/dashboard/list',
                              arguments: {'filter': label},
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Timeline / Secondary info (row-only list)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TimelineSection(
                          groups: data.timelineGroups,
                          onItemTap: (raw) {
                            final title = (raw['title'] != null)
                                ? raw['title'].toString()
                                : 'Event';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Tapped: $title')),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
