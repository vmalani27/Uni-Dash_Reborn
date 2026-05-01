import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/academic_item_actions.dart';

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
    final summary = (item.summary?.trim().isNotEmpty ?? false)
        ? item.summary!.trim()
        : (item.aiSummary?.trim().isNotEmpty ?? false)
            ? item.aiSummary!.trim()
        : item.description.trim();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.entityType.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.9,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
            ),
            const SizedBox(height: 12),
            _DetailSection(
              title: 'Summary',
              child: Text(
                summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.55,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _DetailSection(
              title: 'Full email',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (item.dueDate != null) ...[
              Text(
                'Due: ${item.dueDate!.toLocal()}'.split('.').first,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                    ),
              ),
              const SizedBox(height: 12),
            ],
            AcademicItemActionBar(
              onMarkDone: _working
                  ? null
                  : () => _doAction(
                        () => BackendService.markAcademicItemDone(item.id),
                        'Marked as done',
                      ),
              onAddToCalendar: _working
                  ? null
                  : () => _doAction(
                        () => BackendService.addAcademicItemToCalendar(item.id),
                        'Added to calendar',
                      ),
              onDismiss: _working
                  ? null
                  : () => _doAction(
                        () => BackendService.dismissAcademicItem(item.id),
                        'Dismissed',
                      ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text('Metadata', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (item.courseCode != null) Text('Course: ${item.courseCode}'),
            if (item.professor != null) Text('Professor: ${item.professor}'),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

