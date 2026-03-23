import 'package:flutter/material.dart';

class CategoryOverview extends StatelessWidget {
  final Map<String, int> counts;
  final void Function(String) onSelect;

  const CategoryOverview({
    super.key,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: entries.map((e) {
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(e.key),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.06),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    e.key,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    e.value.toString(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
