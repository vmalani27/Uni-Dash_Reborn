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
                  color: Theme.of(context).brightness == Brightness.light
                      ? meta.tint(0.08)  // Slightly stronger background in light mode
                      : meta.tint(0.05),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: meta.color.withOpacity(
                      Theme.of(context).brightness == Brightness.light ? 0.25 : 0.10,
                    ),
                    width: Theme.of(context).brightness == Brightness.light ? 1.5 : 1,
                  ),
                  boxShadow: Theme.of(context).brightness == Brightness.light
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
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
