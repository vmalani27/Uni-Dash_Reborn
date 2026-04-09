import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/search_result_card.dart';

/// Displays a category section with a header (count badge) and list of result cards.
class SearchResultSection extends StatelessWidget {
  final String category;
  final List<AcademicItem> items;
  final Function(AcademicItem) onItemTap;

  const SearchResultSection({
    super.key,
    required this.category,
    required this.items,
    required this.onItemTap,
  });

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
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

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header with count badge
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Text(
                category,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Result cards
        ...items.map((item) => SearchResultCard(
          item: item,
          onTap: () => onItemTap(item),
        )),
        // Divider after section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ],
    );
  }
}
