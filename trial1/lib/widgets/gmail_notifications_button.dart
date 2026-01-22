import 'package:flutter/material.dart';

import 'package:trial1/services/api_services.dart';

class GmailNotificationPreview {
  final int id;
  final String gmailId;
  final String sender;
  final String subject;
  final String snippet;
  final DateTime? internalDate;

  GmailNotificationPreview({
    required this.id,
    required this.gmailId,
    required this.sender,
    required this.subject,
    required this.snippet,
    this.internalDate,
  });

  factory GmailNotificationPreview.fromJson(Map<String, dynamic> json) {
    return GmailNotificationPreview(
      id: json['id'] as int,
      gmailId: json['gmail_id'] as String,
      sender: json['sender'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
      internalDate: json['internal_date'] != null
          ? DateTime.tryParse(json['internal_date'])
          : null,
    );
  }

  @override
  String toString() {
    return 'GmailNotificationPreview(id: $id, gmailId: $gmailId, sender: $sender, subject: $subject, snippet: $snippet, internalDate: $internalDate)';
  }
}

class GmailMessageDetail {
  final int id;
  final String gmailId;
  final String? threadId;
  final String sender;
  final String subject;
  final String bodyHtml;
  final String bodyText;
  final DateTime? internalDate;

  GmailMessageDetail({
    required this.id,
    required this.gmailId,
    this.threadId,
    required this.sender,
    required this.subject,
    required this.bodyHtml,
    required this.bodyText,
    this.internalDate,
  });

  factory GmailMessageDetail.fromJson(Map<String, dynamic> json) {
    return GmailMessageDetail(
      id: json['id'] as int,
      gmailId: json['gmail_id'] as String,
      threadId: json['thread_id'] as String?,
      sender: json['sender'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      bodyHtml: json['body_html'] as String? ?? '',
      bodyText: json['body_text'] as String? ?? '',
      internalDate: json['internal_date'] != null
          ? DateTime.tryParse(json['internal_date'])
          : null,
    );
  }
}

class GmailNotificationsButton extends StatefulWidget {
  const GmailNotificationsButton({super.key});

  @override
  State<GmailNotificationsButton> createState() =>
      _GmailNotificationsButtonState();
}

class _GmailNotificationsButtonState extends State<GmailNotificationsButton> {
  bool _loading = false;
  String? _error;
  List<GmailNotificationPreview>? _notifications;

  Future<void> _fetchNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
      _notifications = null;
    });
    try {
      debugPrint('[GMAIL DEBUG] Fetching notification previews...');
      final rawList = await BackendService.fetchGmailNotificationPreviews();
      debugPrint('[GMAIL DEBUG] Raw list:');
      debugPrint(rawList.runtimeType.toString());
      debugPrint(rawList.toString());
      final notifications = rawList
          .map<GmailNotificationPreview>(
            (n) {
              try {
                final notif = GmailNotificationPreview.fromJson(n as Map<String, dynamic>);
                debugPrint('[GMAIL DEBUG] Parsed notification: $notif');
                return notif;
              } catch (err) {
                debugPrint('[GMAIL DEBUG] Error parsing notification: $err, data: $n');
                rethrow;
              }
            },
          )
          .toList();
      setState(() {
        _notifications = notifications;
      });
    } catch (e, stack) {
      debugPrint('[GMAIL DEBUG] Error: $e');
      debugPrint(stack.toString());
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showMailDetail(String gmailId) async {
    debugPrint('[GMAIL DEBUG] Fetching mail detail for: $gmailId');
    final cardColor = const Color(0xFFC8C8C8);
    final borderRadius = BorderRadius.circular(22);
    final subjectStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );
    final senderStyle = const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: Colors.black54,
    );
    final bodyStyle = const TextStyle(
      fontSize: 14,
      color: Colors.black,
    );
    final mutedStyle = const TextStyle(
      fontSize: 13,
      color: Colors.black54,
    );
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>>(
          future: BackendService.fetchGmailMessageDetail(gmailId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                backgroundColor: cardColor,
                shape: RoundedRectangleBorder(borderRadius: borderRadius),
                content: const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (snapshot.hasError) {
              debugPrint('[GMAIL DEBUG] Error fetching mail detail: ${snapshot.error}');
              return AlertDialog(
                backgroundColor: cardColor,
                shape: RoundedRectangleBorder(borderRadius: borderRadius),
                title: const Text('Error', style: TextStyle(color: Colors.red)),
                content: Text(snapshot.error.toString(), style: mutedStyle),
              );
            }
            debugPrint('[GMAIL DEBUG] Mail detail data: ${snapshot.data}');
            final mail = GmailMessageDetail.fromJson(snapshot.data!);
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
              title: Text(mail.subject, style: subjectStyle),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: ${mail.sender}', style: senderStyle),
                    if (mail.internalDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0, bottom: 8.0),
                        child: Text(_formatTime(mail.internalDate!), style: mutedStyle),
                      ),
                    if (mail.bodyText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(mail.bodyText, style: bodyStyle),
                      ),
                    if (mail.bodyHtml.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('[HTML body available]', style: mutedStyle),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFFE59A23),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the same background and card style as Login/Register
    final cardColor = const Color(0xFFC8C8C8); // login card bg
    final borderRadius = BorderRadius.circular(22); // login card radius
    final highlightColor = const Color(0xFFE59A23); // primary orange
    final mutedText = Colors.black54;
    final subjectStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    );
    final senderStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.black54,
    );
    final snippetStyle = const TextStyle(
      fontSize: 13,
      color: Colors.black54,
    );
    final timeStyle = const TextStyle(
      fontSize: 12,
      color: Colors.black54,
      fontWeight: FontWeight.w400,
    );

    return SizedBox(
      height: 500, // or MediaQuery.of(context).size.height * 0.7 for responsive
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mail, size: 20),
              label: const Text('Fetch Gmail Notifications'),
              onPressed: _loading ? null : _fetchNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: highlightColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          if (_notifications != null)
            // Use Expanded to allow scrolling, and ListView.separated for spacing
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _notifications!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final n = _notifications![index];
                  // Use Material+InkWell for custom card style
                  return Material(
                    color: cardColor,
                    borderRadius: borderRadius,
                    elevation: 1.5, // soft shadow
                    child: InkWell(
                      borderRadius: borderRadius,
                      onTap: () => _showMailDetail(n.gmailId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Subject: bold, single line
                                  Text(
                                    n.subject,
                                    style: subjectStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  // Sender: medium, single line
                                  Text(
                                    n.sender,
                                    style: senderStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  // Snippet: muted, max 2 lines
                                  Text(
                                    n.snippet,
                                    style: snippetStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Time: subtle, right-aligned
                            if (n.internalDate != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Text(
                                  _formatTime(n.internalDate!),
                                  style: timeStyle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Format time as HH:mm or date if not today
  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }
  }
