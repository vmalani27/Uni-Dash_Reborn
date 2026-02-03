import 'package:flutter/material.dart';

import 'package:trial1/services/app_services.dart';
import 'package:trial1/services/smart_gmail_service.dart';
import 'package:trial1/services/gmail_cache_service.dart';

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

class _GmailNotificationsButtonState extends State<GmailNotificationsButton>
    with WidgetsBindingObserver {
  bool _loading = false;
  String? _error;
  List<GmailNotificationPreview>? _notifications;
  String _syncStatus = 'completed'; // 'pending' or 'completed'
  bool _syncInProgress = false; // Prevent duplicate syncs

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SmartGmailService.startPeriodicRefresh();
    _initializeSync(); // Check and trigger sync if needed
  }

  /// Initialize: Check sync status and auto-sync if needed
  Future<void> _initializeSync() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uid = await BackendService.getCurrentUid();

      // Check sync status
      String status;
      try {
        status = await BackendService.fetchGmailSyncStatus(uid);
      } catch (e) {
        // No status found - need initial sync
        status = 'no_status';
      }

      print('[GMAIL] Sync status: $status');

      // Decide if sync is needed
      bool needsSync = false;
      String syncType = 'full';

      if (status == 'no_status' || status == 'failed') {
        // No sync ever or last sync failed - do full sync
        needsSync = true;
        syncType = 'full';
        print('[GMAIL] Triggering initial full sync');
      } else if (status == 'completed') {
        // Check if data is stale
        final stats = await BackendService.getGmailSyncStats(uid);
        final finishedAt = stats['finished_at']; // When the sync last ran
        final totalStored = stats['total_messages_stored'] ?? 0;

        if (finishedAt != null && totalStored > 0) {
          final lastSync = DateTime.parse(finishedAt);
          final timeSinceSync = DateTime.now().difference(lastSync);

          // Only trigger incremental sync if:
          // 1. Data is stale (>10 min since last sync check)
          // 2. We have messages in DB (initial sync completed)
          if (timeSinceSync.inMinutes > 10) {
            needsSync = true;
            syncType = 'incremental';
            print(
              '[GMAIL] Data stale (${timeSinceSync.inMinutes} min since last sync) - triggering incremental sync',
            );
          }
        } else if (totalStored == 0) {
          // Completed status but no messages - trigger full sync
          needsSync = true;
          syncType = 'full';
          print(
            '[GMAIL] No messages in DB despite completed status - triggering full sync',
          );
        }
      }

      // Trigger sync if needed (non-blocking)
      if (needsSync) {
        if (syncType == 'full') {
          BackendService.triggerGmailSync(uid);
        } else {
          BackendService.triggerIncrementalSync(uid);
        }

        // Show subtle indicator
        setState(() {
          _syncStatus = 'pending';
        });

        // Wait for sync to potentially complete
        await Future.delayed(const Duration(seconds: 2));

        // Clear cache to fetch fresh data from DB after sync
        await GmailCacheService.clearCache();
      }

      // Load from DB (if sync ran, cache is cleared so we get fresh data)
      await _smartFetchNotifications();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SmartGmailService.stopPeriodicRefresh();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    SmartGmailService.setAppActive(state == AppLifecycleState.resumed);

    // When app resumes, fetch fresh data (periodic sync may have run in background)
    if (state == AppLifecycleState.resumed) {
      _fetchFreshOnResume();
    }
  }

  /// Fetch fresh data when app resumes (bypass cache to get any background sync updates)
  Future<void> _fetchFreshOnResume() async {
    print('[GMAIL] App resumed - fetching fresh data');
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Clear cache to ensure we get fresh data from DB
      await GmailCacheService.clearCache();

      // Fetch fresh from database
      final notifications =
          await BackendService.fetchGmailNotificationPreviewsSmart();

      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Smart fetch that uses caching and background sync
  Future<void> _smartFetchNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifications = await SmartGmailService.smartFetch();
      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Force refresh (user button press) - NOW DEPRECATED, keeping for compatibility
  Future<void> _forceRefresh() async {
    await _handlePullToRefresh();
  }

  /// Pull-to-refresh handler (incremental sync)
  Future<void> _handlePullToRefresh() async {
    // Prevent duplicate syncs
    if (_syncInProgress) {
      print('[GMAIL] Sync already in progress, skipping');
      return;
    }

    print('[GMAIL] Pull-to-refresh triggered');
    _syncInProgress = true;

    setState(() {
      _error = null;
    });

    try {
      final uid = await BackendService.getCurrentUid();

      // Trigger incremental sync (non-blocking)
      await BackendService.triggerIncrementalSync(uid);

      setState(() {
        _syncStatus = 'pending';
      });

      // Wait briefly for sync to complete
      await Future.delayed(const Duration(seconds: 3));

      // Fetch updated data from DB
      await GmailCacheService.clearCache();
      final notifications =
          await BackendService.fetchGmailNotificationPreviewsSmart();

      setState(() {
        _notifications = notifications;
        _syncStatus = 'completed';
      });

      print('[GMAIL] Pull-to-refresh completed');
    } catch (e) {
      setState(() {
        _error = e.toString();
        _syncStatus = 'failed';
      });
      print('[GMAIL] Pull-to-refresh failed: $e');
    } finally {
      _syncInProgress = false;
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
    final bodyStyle = const TextStyle(fontSize: 14, color: Colors.black);
    final mutedStyle = const TextStyle(fontSize: 13, color: Colors.black54);
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
              debugPrint(
                '[GMAIL DEBUG] Error fetching mail detail: ${snapshot.error}',
              );
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
                        child: Text(
                          _formatTime(mail.internalDate!),
                          style: mutedStyle,
                        ),
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
                    child: Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
    final snippetStyle = const TextStyle(fontSize: 13, color: Colors.black54);
    final timeStyle = const TextStyle(
      fontSize: 12,
      color: Colors.black54,
      fontWeight: FontWeight.w400,
    );

    return SizedBox(
      height: 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Subtle sync status indicator (non-blocking)
          if (_syncStatus == 'pending')
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: highlightColor.withOpacity(0.1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(highlightColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Syncing emails...',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_notifications != null)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handlePullToRefresh,
                color: highlightColor,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _notifications!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final n = _notifications![index];
                    return Material(
                      color: cardColor,
                      borderRadius: borderRadius,
                      elevation: 1.5,
                      child: InkWell(
                        borderRadius: borderRadius,
                        onTap: () => _showMailDetail(n.gmailId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.subject,
                                      style: subjectStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      n.sender,
                                      style: senderStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      n.snippet,
                                      style: snippetStyle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (n.internalDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 2,
                                  ),
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
            ),
        ],
      ),
    );
  }

  // Format time as HH:mm or date if not today (converts to local timezone)
  String _formatTime(DateTime dt) {
    // Convert UTC to local timezone (IST for Indian users)
    final localTime = dt.toLocal();
    final now = DateTime.now();

    if (localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day) {
      return "${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}";
    } else {
      return "${localTime.day}/${localTime.month}/${localTime.year}";
    }
  }
}
