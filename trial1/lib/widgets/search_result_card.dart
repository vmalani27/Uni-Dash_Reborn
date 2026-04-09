import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';

/// Individual search result card with category indicator, title, and summary.
class SearchResultCard extends StatelessWidget {
  final AcademicItem item;
  final VoidCallback onTap;

  const SearchResultCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  Color _getCategoryColor(String? category) {
    switch (category?.toUpperCase()) {
      case 'ASSIGNMENT':
        return Colors.blue;
      case 'EXAM':
        return Colors.red;
      case 'OPPORTUNITY':
        return Colors.green;
      case 'ACADEMIC_ADMIN':
        return Colors.orange;
      case 'INFORMATION':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    if (dueDateOnly == today) {
      return 'Today';
    } else if (dueDateOnly == tomorrow) {
      return 'Tomorrow';
    } else if (dueDateOnly.isBefore(today)) {
      return 'Overdue';
    } else {
      return dueDateOnly.toString().split(' ')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(item.entityType);
    final dueDateText = _formatDueDate(item.dueDate);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            // Light mode: visible borders for card separation
            border: Theme.of(context).brightness == Brightness.light
                ? Border(
                    left: BorderSide(
                      color: categoryColor,
                      width: 4,
                    ),
                    right: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    top: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  )
                : Border(
                    left: BorderSide(
                      color: categoryColor,
                      width: 4,
                    ),
                  ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              // Title + Summary column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (item.aiSummary != null && item.aiSummary!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.aiSummary!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Due date badge
              if (dueDateText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dueDateText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: categoryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
