import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/academic_item_card.dart';

class FocusSection extends StatelessWidget {
  final List<AcademicItem> items;
  final Function(AcademicItem) onItemTap;

  const FocusSection({super.key, required this.items, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Text(
                'Focus Today',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // We can use a special "Focus" card style here if needed,
        // but for now let's use the standard card in a list.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: items
                .map(
                  (item) => AcademicItemCard(
                    item: item,
                    onTap: () => onItemTap(item),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
