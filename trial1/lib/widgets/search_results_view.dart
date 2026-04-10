import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/search_result_section.dart';

/// Main search results view that displays all filtered results grouped by category.
class SearchResultsView extends StatelessWidget {
  final String query;
  final List<AcademicItem> allItems;
  final Function(AcademicItem) onResultTap;

  const SearchResultsView({
    super.key,
    required this.query,
    required this.allItems,
    required this.onResultTap,
  });

  /// Filter items by query string across multiple fields
  List<AcademicItem> _filterItems(String query) {
    if (query.isEmpty) return [];
    
    final searchLower = query.toLowerCase();
    
    return allItems.where((item) {
      final titleMatch = item.title.toLowerCase().contains(searchLower);
      final summaryMatch = (item.aiSummary?.toLowerCase() ?? '').contains(searchLower);
      final categoryMatch = (item.entityType?.toLowerCase() ?? '').contains(searchLower);
      final descriptionMatch = item.description.toLowerCase().contains(searchLower);
      
      return titleMatch || summaryMatch || categoryMatch || descriptionMatch;
    }).toList();
  }

  /// Group filtered results by category
  Map<String, List<AcademicItem>> _groupByCategory(List<AcademicItem> items) {
    final groups = <String, List<AcademicItem>>{
      'ASSIGNMENT': [],
      'EXAM': [],
      'OPPORTUNITY': [],
      'ACADEMIC_ADMIN': [],
      'INFORMATION': [],
    };

    for (final item in items) {
      final type = item.entityType.toUpperCase();
      if (groups.containsKey(type)) {
        groups[type]!.add(item);
      }
    }

    // Remove empty groups
    groups.removeWhere((_, items) => items.isEmpty);

    return groups;
  }

  /// Format category name for display
  String _formatCategoryName(String category) {
    switch (category) {
      case 'ASSIGNMENT':
        return 'Assignments';
      case 'EXAM':
        return 'Exams';
      case 'OPPORTUNITY':
        return 'Opportunities';
      case 'ACADEMIC_ADMIN':
        return 'Announcements';
      case 'INFORMATION':
        return 'Information';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _filterItems(query);

    if (results.isEmpty) {
      return _buildEmptyState(context);
    }

    final grouped = _groupByCategory(results);
    final categoryOrder = ['ASSIGNMENT', 'EXAM', 'OPPORTUNITY', 'ACADEMIC_ADMIN', 'INFORMATION'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Results header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(
              '${results.length} result${results.length != 1 ? 's' : ''} found',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          // Grouped sections
          ...categoryOrder
              .where((category) => grouped.containsKey(category))
              .map((category) => SearchResultSection(
            category: _formatCategoryName(category),
            items: grouped[category]!,
            onItemTap: onResultTap,
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check your spelling',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
