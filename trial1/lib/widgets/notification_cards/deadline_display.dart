import 'package:flutter/material.dart';
import 'package:trial1/utils/time_formatters.dart';

/// Deadline display badge widget.
/// Single responsibility: render deadline with appropriate color.
class DeadlineDisplay extends StatelessWidget {
  final DateTime? deadline;

  const DeadlineDisplay({
    super.key,
    required this.deadline,
  });

  @override
  Widget build(BuildContext context) {
    if (deadline == null) return const SizedBox.shrink();

    try {
      final (timeText, colorName) = getDeadlineDisplay(deadline);
      
      if (timeText.isEmpty) return const SizedBox.shrink();

      // Map color names to actual colors
      Color timeColor;
      switch (colorName) {
        case 'red':
          timeColor = Colors.red.shade400;
        case 'orange':
          timeColor = Colors.orange.shade400;
        case 'yellow':
          timeColor = Colors.yellow.shade600;
        default:
          timeColor = Colors.grey;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: timeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          timeText,
          style: TextStyle(
            color: timeColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}
