import 'package:flutter/material.dart';
import '../models/academic_models.dart';

class ItemCard extends StatelessWidget {
  final AcademicItem item;
  const ItemCard({super.key, required this.item});

  // Convenience constructor for previously-used ItemSummary shape
  const ItemCard.fromAcademic({super.key, required AcademicItem item}) : item = item;

  String _countdownText(DateTime? d) {
    if (d == null) return 'No deadline';
    try {
      final dt = d.toLocal();
      final diff = dt.difference(DateTime.now());
      if (diff.inDays > 1) return 'Due in ${diff.inDays} days';
      if (diff.inHours >= 1) return 'Due in ${diff.inHours} hrs';
      if (diff.inMinutes >= 1) return 'Due in ${diff.inMinutes} mins';
      return 'Due soon';
    } catch (_) {
      return 'Due: ${d.toIso8601String()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/item', arguments: item),
      borderRadius: BorderRadius.circular(8),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Chip(label: Text(item.entityType)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _countdownText(item.dueDate),
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Score: ${item.academicScore}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/item', arguments: item),
                    child: const Text('Open'),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
