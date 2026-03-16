import 'package:flutter/material.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/widgets/notification_cards/priority_dot.dart';
import 'package:trial1/widgets/notification_cards/deadline_display.dart';
import 'package:trial1/theme.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trial1/config.dart';

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
  StreamSubscription<String>? _streamSubscription;
  http.Client? _httpClient;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    // Default to raw view if AI hasn't processed it yet
    if (!_message.aiProcessed) {
      _selectedView = 'raw';
      _listenToAiStream();
    }
  }

  void _listenToAiStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final idToken = await user.getIdToken();

    final url = Uri.parse(
      '${AppConfig.backendUrl}/gmail/${widget.gmailId}/ai/stream',
    );
    _httpClient = http.Client();
    final request = http.Request('GET', url);
    request.headers['Authorization'] = 'Bearer $idToken';
    request.headers['Accept'] = 'text/event-stream';

    try {
      final response = await _httpClient!.send(request);
      if (response.statusCode == 200) {
        _streamSubscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (line.startsWith('data: ')) {
                  final dataStr = line.substring(6);
                  if (dataStr.trim().isEmpty) return;
                  try {
                    final data = jsonDecode(dataStr);
                    if (data['status'] == 'completed') {
                      if (mounted) {
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
                            aiSummary: data['ai_summary'],
                            aiLabelTopic: data['ai_label_topic'],
                            aiLabelUrgency: data['ai_label_urgency'],
                            aiLabelSource: data['ai_label_source'],
                            aiProcessed: true,
                            deadlineIso: data['deadline_iso'] != null
                                ? DateTime.tryParse(data['deadline_iso'])
                                : null,
                            deadlineConfidence: data['deadline_confidence'],
                            academicScore:
                                (data['academic_score'] as num?)?.toDouble() ??
                                0.0,
                          );
                          _selectedView = 'ai';
                        });
                      }
                    }
                  } catch (e) {
                    debugPrint('Error parsing stream data: $e');
                  }
                }
              },
              onError: (e) {
                debugPrint('Stream error: $e');
              },
            );
      }
    } catch (e) {
      debugPrint('Error listening to AI stream: $e');
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: Theme.of(context).colorScheme.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Theme.of(context).colorScheme.onBackground,
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
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            _message.sender.isNotEmpty
                                ? _message.sender[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
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
                                  return Theme.of(context).colorScheme.primary.withOpacity(0.15);
                                }
                                return Colors.transparent;
                              }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith<Color>((
                                Set<WidgetState> states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return Theme.of(context).colorScheme.primary;
                                }
                                return Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
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
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).disabledColor.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        _message.bodyText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: null, // Use default icon color
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Analysis',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
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
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
                color: kUrgencyHigh.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kUrgencyHigh.withOpacity(0.2)),
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _message.aiSummary!,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.6, color: Theme.of(context).colorScheme.onBackground),
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
