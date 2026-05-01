import 'package:flutter/material.dart';

class FeatureList extends StatelessWidget {
  const FeatureList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _FeatureRow(icon: Icons.folder_open_outlined, text: 'Organized course updates'),
        SizedBox(height: 8),
        _FeatureRow(icon: Icons.notifications_active_outlined, text: 'Deadline tracking'),
        SizedBox(height: 8),
        _FeatureRow(icon: Icons.view_list_outlined, text: 'Clear priority view'),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75), fontSize: 15)),
      ],
    );
  }
}

