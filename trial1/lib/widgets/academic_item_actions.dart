import 'package:flutter/material.dart';

class AcademicItemActionBar extends StatelessWidget {
  final VoidCallback? onMarkDone;
  final VoidCallback? onAddToCalendar;
  final VoidCallback? onDismiss;

  const AcademicItemActionBar({
    super.key,
    required this.onMarkDone,
    required this.onAddToCalendar,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: onMarkDone,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Mark done'),
        ),
        FilledButton.tonalIcon(
          onPressed: onAddToCalendar,
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Calendar'),
        ),
        OutlinedButton.icon(
          onPressed: onDismiss,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Dismiss'),
        ),
      ],
    );
  }
}
