import 'package:flutter/material.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/widgets/common/semantic_badge.dart';

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
    final entries = [
      _CategoryEntry('Assignments', 'ASSIGNMENT'),
      _CategoryEntry('Exams', 'EXAM'),
      _CategoryEntry('Opportunities', 'OPPORTUNITY'),
      _CategoryEntry('Announcements', 'ACADEMIC_ADMIN'),
    ];

    return Row(
      children: entries.map((entry) {
        final meta = academicCategoryMeta(entry.topicKey);
        final value = counts[entry.label] ?? counts[entry.topicKey] ?? 0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => onSelect(entry.label),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: meta.tint(0.05),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: meta.color.withOpacity(0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CategoryBadge(
                          topic: meta.key,
                          label: meta.label,
                          icon: meta.icon,
                          compact: true,
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: meta.color.withOpacity(0.56),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value.toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.62),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryEntry {
  final String label;
  final String topicKey;

  const _CategoryEntry(this.label, this.topicKey);
}
