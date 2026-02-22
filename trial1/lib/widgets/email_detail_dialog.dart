import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/widgets/notification_cards/priority_dot.dart';
import 'package:trial1/widgets/notification_cards/deadline_display.dart';
import 'package:trial1/theme.dart';

/// Email detail screen with AI insights.
class EmailDetailScreen extends StatefulWidget {
  final GmailMessageDetail initialMessage;
  final String gmailId;

  const EmailDetailScreen({
    super.key,
    required this.initialMessage,
    required this.gmailId,
  });

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  late GmailMessageDetail _message;
  String _selectedView = 'ai'; // 'ai' or 'raw'

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    // Default to raw view if AI hasn't processed it yet
    if (!_message.aiProcessed) {
      _selectedView = 'raw';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgPrimary,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: kBgPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: kTextPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject
                  Text(
                    _message.subject,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.3),
                  ),
                  const SizedBox(height: 16),

                  // Sender row
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kAccentPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            _message.sender.isNotEmpty
                                ? _message.sender[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: kAccentPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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
                              _message.sender,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              _message.internalDate != null
                                  ? _formatDate(_message.internalDate!)
                                  : 'Unknown Date',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // View Toggle
                  if (_message.aiProcessed) ...[
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'ai',
                            label: Text('AI Summary'),
                            icon: Icon(Icons.auto_awesome),
                          ),
                          ButtonSegment<String>(
                            value: 'raw',
                            label: Text('Raw Email'),
                            icon: Icon(Icons.mail_outline),
                          ),
                        ],
                        selected: {_selectedView},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedView = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>((
                                Set<WidgetState> states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return kAccentPrimary.withValues(alpha: 0.15);
                                }
                                return Colors.transparent;
                              }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith<Color>((
                                Set<WidgetState> states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return kAccentPrimary;
                                }
                                return kTextSecondary;
                              }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Content based on toggle
                  if (_selectedView == 'ai' && _message.aiProcessed)
                    _buildAiSection(context)
                  else
                    // Raw Email Body
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kBgSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kTextDisabled.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        _message.bodyText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: kTextPrimary,
                          height: 1.7,
                        ),
                      ),
                    ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccentPrimary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: kAccentPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + chips row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kAccentPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: kAccentPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Analysis',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: kAccentPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              PriorityDot(academicScore: _message.academicScore),
            ],
          ),
          const SizedBox(height: 16),

          // Topic + Urgency chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_message.aiLabelTopic != null)
                _buildChip(
                  _message.aiLabelTopic!,
                  topicColor(_normalizeTopicFromLabel(_message.aiLabelTopic!)),
                  topicIcon(_normalizeTopicFromLabel(_message.aiLabelTopic!)),
                ),
              if (_message.aiLabelUrgency != null)
                _buildChip(
                  _message.aiLabelUrgency!,
                  urgencyColor(_message.aiLabelUrgency),
                  Icons.flag_outlined,
                ),
              if (_message.aiLabelSource != null)
                _buildChip(
                  _message.aiLabelSource!,
                  kTextSecondary,
                  Icons.verified_user_outlined,
                ),
            ],
          ),

          // Deadline
          if (_message.deadlineIso != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kUrgencyHigh.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kUrgencyHigh.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: kUrgencyHigh, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DeadlineDisplay(deadline: _message.deadlineIso),
                  ),
                ],
              ),
            ),
          ],

          // Summary
          if (_message.aiSummary != null && _message.aiSummary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              'Summary',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: kTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _message.aiSummary!,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6, color: kTextPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeTopicFromLabel(String label) {
    switch (label) {
      case 'Assignment or Submission':
        return 'ASSIGNMENT';
      case 'Exam Notifications':
        return 'EXAM';
      case 'Timetable / Schedule Update':
        return 'ACADEMIC_ADMIN';
      case 'Administrative / Fees / Counselling':
        return 'ACADEMIC_ADMIN';
      case 'Internship / Placement Opportunities':
        return 'OPPORTUNITY';
      case 'Events / Hackathons':
        return 'OPPORTUNITY';
      case 'Certification / Courses':
        return 'OPPORTUNITY';
      case 'Important Announcements':
        return 'INFORMATION';
      case 'General Information / Misc':
        return 'INFORMATION';
      default:
        return 'OTHER';
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · ${hour == 0 ? 12 : hour}:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }
}
