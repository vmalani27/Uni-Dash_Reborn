import 'package:flutter/material.dart';

/// Shared priority dot widget
/// Single responsibility: visual priority indicator
class PriorityDot extends StatelessWidget {
  final double academicScore;

  const PriorityDot({
    super.key,
    required this.academicScore,
  });

  Color _getDotColor() {
    if (academicScore >= 20) {
      return Colors.red.shade400;
    } else if (academicScore >= 15) {
      return Colors.orange.shade400;
    } else if (academicScore >= 10) {
      return Colors.yellow.shade600;
    } else {
      return Colors.green.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getDotColor(),
        shape: BoxShape.circle,
      ),
    );
  }
}
