import 'package:flutter/material.dart';
import 'package:trial1/models/academic_event.dart';

class TimelineList extends StatelessWidget {
  final List<AcademicEvent> today;
  final List<AcademicEvent> thisWeek;
  final void Function(AcademicEvent) onTapEvent;

  const TimelineList({
    super.key,
    required this.today,
    required this.thisWeek,
    required this.onTapEvent,
  });

  Widget _row(String title, List<AcademicEvent> items) {
    if (items.isEmpty) {
      return SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Column(
          children: items.map((e) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: e.deadline != null ? Text('${e.deadline}') : null,
              trailing: Text(e.urgency, style: const TextStyle(fontSize: 12)),
              onTap: () => onTapEvent(e),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('Today', today),
        const SizedBox(height: 12),
        _row('This Week', thisWeek),
      ],
    );
  }
}
