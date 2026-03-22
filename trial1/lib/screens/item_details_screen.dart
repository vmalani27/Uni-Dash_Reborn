import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/services/api_services.dart';

class ItemDetailsScreen extends StatefulWidget {
  final AcademicItem item;

  const ItemDetailsScreen({super.key, required this.item});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  bool _working = false;

  Future<void> _doAction(
    Future<void> Function() action,
    String successMsg,
  ) async {
    setState(() => _working = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMsg)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        actions: [
          if (_working)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(item.entityType)),
            const SizedBox(height: 12),
            Text(
              item.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (item.dueDate != null) ...[
              Text(
                'Due: ${item.dueDate!.toLocal()}'.split('.').first,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _doAction(
                          () => BackendService.markAcademicItemDone(item.id),
                          'Marked as done',
                        ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark Done'),
                ),
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _doAction(
                          () =>
                              BackendService.addAcademicItemToCalendar(item.id),
                          'Added to calendar',
                        ),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Add to Calendar'),
                ),
                TextButton.icon(
                  onPressed: _working
                      ? null
                      : () => _doAction(
                          () => BackendService.dismissAcademicItem(item.id),
                          'Dismissed',
                        ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Dismiss'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text('Metadata', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('Score: ${item.academicScore}'),
            if (item.courseCode != null) Text('Course: ${item.courseCode}'),
            if (item.professor != null) Text('Professor: ${item.professor}'),
          ],
        ),
      ),
    );
  }
}
