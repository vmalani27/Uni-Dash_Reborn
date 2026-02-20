import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/widgets/notification_cards/priority_dot.dart';
import 'package:trial1/widgets/notification_cards/deadline_display.dart';
import 'package:trial1/theme.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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
  StreamSubscription? _aiSubscription;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    if (!widget.initialMessage.aiProcessed) {
      _startAiStreaming();
    }
  }

  @override
  void dispose() {
    _aiSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startAiStreaming() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final url = Uri.parse(
        '${BackendService.baseUrl}/gmail/${widget.gmailId}/ai/stream',
      );
      final idToken = await user.getIdToken();

      final request = http.Request('GET', url);
      request.headers['Authorization'] = 'Bearer $idToken';
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) return;

      _aiSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (line.startsWith('data: ')) {
                final jsonStr = line.substring(6).trim();
                if (jsonStr.isEmpty) return;
                try {
                  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                  if (data['status'] == 'completed' && mounted) {
                    setState(() {
                      _message = GmailMessageDetail(
                        id: _message.id,
                        gmailId: _message.gmailId,
                        threadId: _message.threadId,
                        sender: _message.sender,
                        subject: _message.subject,
                        bodyHtml: _message.bodyHtml,
                        bodyText: _message.bodyText,
                        internalDate: _message.internalDate,
                        aiSummary: data['ai_summary'] as String?,
                        aiLabelTopic: data['ai_label_topic'] as String?,
                        aiLabelUrgency: data['ai_label_urgency'] as String?,
                        aiLabelSource: data['ai_label_source'] as String?,
                        aiProcessed: true,
                        deadlineIso: _message.deadlineIso,
                        deadlineConfidence: _message.deadlineConfidence,
                        academicScore: _message.academicScore,
                      );
                    });
                  }
                } catch (e) {
                  // Ignore parse errors
                }
              }
            },
            onError: (_) {},
            onDone: () => client.close(),
          );
    } catch (_) {}
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
                          color: kAccentPrimary.withOpacity(0.15),
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
                  const SizedBox(height: 20),

                  // AI Analysis Card
                  _buildAiSection(context),
                  const SizedBox(height: 24),

                  // Email Body
                  Text(
                    _message.bodyText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: kTextPrimary,
                      height: 1.7,
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
    if (!_message.aiProcessed) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kAccentPrimary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kAccentPrimary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kAccentPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Analyzing email…',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: kAccentPrimary),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTextDisabled.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + chips row
          Row(
            children: [
              Icon(Icons.auto_awesome, color: kAccentPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Insights',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontSize: 13),
              ),
              const Spacer(),
              PriorityDot(academicScore: _message.academicScore),
            ],
          ),
          const SizedBox(height: 14),

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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kUrgencyHigh.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, color: kUrgencyHigh, size: 14),
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
            const SizedBox(height: 14),
            Divider(color: kTextDisabled.withOpacity(0.1), height: 1),
            const SizedBox(height: 14),
            Text(
              _message.aiSummary!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
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
        color: color.withOpacity(0.1),
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
