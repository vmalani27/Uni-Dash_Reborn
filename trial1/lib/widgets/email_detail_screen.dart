import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/theme.dart';

/// Full email detail view showing message body, metadata, and AI insights
class EmailDetailScreen extends StatelessWidget {
  final GmailMessageDetail initialMessage;
  final String gmailId;

  const EmailDetailScreen({
    super.key,
    required this.initialMessage,
    required this.gmailId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Details'),
        leading: const CloseButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with from and subject
            _buildHeader(context),
            const SizedBox(height: 20),

            // AI Labels (if available)
            if (initialMessage.aiProcessed) ...[
              _buildAILabels(context),
              const SizedBox(height: 20),
            ],

            // Deadline (if available)
            if (initialMessage.deadlineIso != null) _buildDeadlineCard(context),

            if (initialMessage.deadlineIso != null) const SizedBox(height: 20),

            // Email body
            _buildBodySection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      initialMessage.sender.isNotEmpty
                          ? initialMessage.sender[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        initialMessage.sender,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (initialMessage.internalDate != null)
                        Text(
                          _formatDate(initialMessage.internalDate!),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Subject
            Text(
              initialMessage.subject,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAILabels(BuildContext context) {
    final labels = <(String label, String value, Color color)>[];

    if (initialMessage.aiLabelTopic != null) {
      final topicColor = _getTopicColor(initialMessage.aiLabelTopic!);
      labels.add(('Topic', initialMessage.aiLabelTopic!, topicColor));
    }

    if (initialMessage.aiLabelUrgency != null) {
      final urgencyColor = _getUrgencyColor(initialMessage.aiLabelUrgency!);
      labels.add(('Urgency', initialMessage.aiLabelUrgency!, urgencyColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Insights',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value, color) in labels)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      value,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (initialMessage.aiSummary != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  initialMessage.aiSummary!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeadlineCard(BuildContext context) {
    final deadline = initialMessage.deadlineIso!;
    final now = DateTime.now();
    final diff = deadline.difference(now);
    final isOverdue = diff.isNegative;
    final color = isOverdue
        ? kUrgencyCritical
        : (diff.inDays <= 2 ? kUrgencyHigh : kUrgencyMedium);

    String statusText;
    if (isOverdue) {
      statusText = 'Overdue';
    } else if (diff.inHours < 1) {
      statusText = 'Due very soon';
    } else if (diff.inHours < 24) {
      statusText = 'Due today';
    } else if (diff.inDays == 1) {
      statusText = 'Due tomorrow';
    } else if (diff.inDays <= 7) {
      statusText = 'Due in ${diff.inDays} days';
    } else {
      statusText = 'Due ${deadline.day}/${deadline.month}/${deadline.year}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deadline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statusText,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Message',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            initialMessage.bodyText.isNotEmpty
                ? initialMessage.bodyText
                : '(No text content)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Color _getTopicColor(String topic) {
    switch (topic.toUpperCase()) {
      case 'ASSIGNMENT':
        return kTopicAssignment;
      case 'EXAM':
        return kTopicExam;
      case 'ACADEMIC_ADMIN':
        return kTopicAcademic;
      case 'OPPORTUNITY':
        return kTopicOpportunity;
      case 'INFORMATION':
        return kTopicInformation;
      default:
        return kTopicOther;
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return kUrgencyCritical;
      case 'high':
        return kUrgencyHigh;
      case 'medium':
        return kUrgencyMedium;
      case 'low':
        return kUrgencyLow;
      default:
        return kUrgencyNone;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (messageDay == today) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
