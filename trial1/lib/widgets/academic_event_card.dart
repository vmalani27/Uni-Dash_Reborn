import 'package:flutter/material.dart';
import 'package:trial1/models/academic_event.dart';
import 'package:trial1/theme.dart';

/// Dashboard card for a single AcademicEvent.
///
/// Displays: type badge + title + course + deadline + urgency + academic score.
/// Taps navigate to email detail view.
class AcademicEventCard extends StatelessWidget {
  final AcademicEvent event;
  final VoidCallback? onTap;
  final bool showCourse;
  final bool showDeadline;

  const AcademicEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showCourse = true,
    this.showDeadline = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: colorScheme.onSurface.withOpacity(0.12),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Type badge + Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeBadge(type: event.type),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (showCourse && event.course != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.course!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Urgency badge (right side)
                _UrgencyBadge(urgency: event.urgency),
              ],
            ),
            const SizedBox(height: 10),

            // Enriched insights (instructor, action items) if available
            if (event.insights != null) ...[
              _InsightsSection(insights: event.insights!),
              const SizedBox(height: 10),
            ],

            // Footer: Deadline + Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showDeadline && event.deadline != null)
                  _DeadlineText(deadline: event.deadline!)
                else
                  const SizedBox(),
                _ScoreIndicator(score: event.academicScore),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Colored badge for event type (Assignment, Exam, Academic, etc.).
class _TypeBadge extends StatelessWidget {
  final AcademicEventType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    final label = _typeLabel(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _typeColor(AcademicEventType type) {
    switch (type) {
      case AcademicEventType.assignment:
        return kTopicAssignment;
      case AcademicEventType.exam:
        return kTopicExam;
      case AcademicEventType.academic:
        return kTopicAcademic;
      case AcademicEventType.opportunity:
        return kTopicOpportunity;
      case AcademicEventType.information:
        return kTopicInformation;
      case AcademicEventType.other:
        return kTopicOther;
    }
  }

  String _typeLabel(AcademicEventType type) {
    switch (type) {
      case AcademicEventType.assignment:
        return 'Assignment';
      case AcademicEventType.exam:
        return 'Exam';
      case AcademicEventType.academic:
        return 'Academic';
      case AcademicEventType.opportunity:
        return 'Opportunity';
      case AcademicEventType.information:
        return 'Info';
      case AcademicEventType.other:
        return 'Other';
    }
  }
}

/// Colored urgency badge (Critical, High, Medium, Low, None).
class _UrgencyBadge extends StatelessWidget {
  final String urgency;

  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final color = urgencyColor(urgency);
    final isMinor = urgency == 'Low' || urgency == 'None';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMinor ? Colors.transparent : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Text(
        urgency,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Countdown text for deadline (e.g., "Due in 3 days").
class _DeadlineText extends StatelessWidget {
  final DateTime deadline;

  const _DeadlineText({required this.deadline});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = deadline.difference(now);

    String label;
    Color color = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    if (diff.isNegative) {
      label = 'Overdue';
      color = kUrgencyCritical;
    } else if (diff.inDays == 0) {
      label = 'Due today';
      color = kUrgencyCritical;
    } else if (diff.inDays == 1) {
      label = 'Due tomorrow';
      color = kUrgencyHigh;
    } else if (diff.inDays < 7) {
      label = 'Due in ${diff.inDays} days';
      color = kUrgencyMedium;
    } else {
      label = 'Due ${deadline.month}/${deadline.day}';
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: diff.inDays <= 1 ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

/// Visual score indicator bar (0-100).
class _ScoreIndicator extends StatelessWidget {
  final double score;

  const _ScoreIndicator({required this.score});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalized = (score / 100).clamp(0.0, 1.0);

    // Color gradient: green (low) → yellow (mid) → red (high)
    Color scoreColor;
    if (normalized < 0.33) {
      scoreColor = kTopicOpportunity; // Green
    } else if (normalized < 0.66) {
      scoreColor = kUrgencyMedium; // Yellow
    } else {
      scoreColor = kUrgencyCritical; // Red
    }

    return Row(
      children: [
        // Score bar
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: colorScheme.onSurface.withOpacity(0.1),
          ),
          child: FractionallySizedBox(
            widthFactor: normalized,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: scoreColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Score text
        Text(
          score.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scoreColor,
          ),
        ),
      ],
    );
  }
}
/// Displays enriched insights: instructor, action items, submission info.
class _InsightsSection extends StatelessWidget {
  final insights;

  const _InsightsSection({
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.1),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructor info
          if (insights.instructorName != null || insights.instructorEmail != null) ...[
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insights.instructorName ?? insights.instructorEmail ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // Action items
          if (insights.actionItems.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.checklist, size: 14, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insights.actionItems.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (insights.actionItems.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '+${insights.actionItems.length - 1} more actions',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],

          // Submission info
          if (insights.submissionRequired) ...[
            Row(
              children: [
                Icon(Icons.upload_file, size: 14, color: kUrgencyMedium),
                const SizedBox(width: 6),
                Text(
                  insights.submissionFormat != null
                      ? 'Submit as ${insights.submissionFormat}'
                      : 'Submission required',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: kUrgencyMedium.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],

          // LLM enrichment badge
          if (insights.enrichedByLlm) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Chip(
                label: const Text('AI enriched'),
                labelStyle: TextStyle(fontSize: 9, color: colorScheme.primary),
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                side: BorderSide.none,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}