import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/theme.dart';
import 'package:trial1/utils/time_formatters.dart';

/// Upcoming deadlines horizontal scroll section.
/// Single responsibility: render horizontal list of deadline cards.
class UpcomingDeadlinesSection extends StatelessWidget {
  final List<GmailNotificationPreview> deadlines;

  const UpcomingDeadlinesSection({
    super.key,
    required this.deadlines,
  });

  @override
  Widget build(BuildContext context) {
    if (deadlines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Upcoming Deadlines',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: deadlines.length,
            itemBuilder: (context, index) {
              final notification = deadlines[index];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatDeadline(notification.deadlineIso!),
                      style: TextStyle(
                        color: kUrgencyHigh,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
