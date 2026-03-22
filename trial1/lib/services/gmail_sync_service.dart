import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/services/smart_gmail_service.dart';
import 'package:trial1/services/api_services.dart';

class GmailSyncServiceResult {
  final List<GmailNotificationPreview> notifications;
  final String syncStatus;

  GmailSyncServiceResult({
    required this.notifications,
    required this.syncStatus,
  });
}

/// Simplified service — backend handles sync autonomously.
/// Frontend only reads current state from the database.
class GmailSyncService {
  /// Load notifications immediately from DB/cache.
  /// No sync trigger — backend ingestion loop handles that.
  static Future<GmailSyncServiceResult> loadNotificationsInstant() async {
    final notifications = await SmartGmailService.smartFetch();

    return GmailSyncServiceResult(
      notifications: notifications,
      syncStatus: 'completed',
    );
  }

  /// Load the complete unified dashboard.
  static Future<Map<String, dynamic>> loadDashboard() async {
    return await BackendService.fetchUnifiedDashboard();
  }
}
