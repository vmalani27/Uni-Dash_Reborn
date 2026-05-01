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

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in entries)
          _OverviewCard(
            entry: entry,
            count: counts[entry.label] ?? counts[entry.topicKey] ?? 0,
            onTap: () => onSelect(entry.label),
          ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final _CategoryEntry entry;
  final int count;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.entry,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = academicCategoryMeta(entry.topicKey);
    return SizedBox(
      width: 190,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: meta.tint(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: meta.color.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: meta.color.withValues(alpha: 0.72),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.03,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEntry {
  final String label;
  final String topicKey;

  const _CategoryEntry(this.label, this.topicKey);
}
