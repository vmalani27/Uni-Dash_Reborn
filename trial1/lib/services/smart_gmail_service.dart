import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/services/gmail_cache_service.dart';

/// Simplified Gmail fetch service — no sync triggers.
/// Backend handles ingestion and AI processing autonomously.
class SmartGmailService {
  /// Smart fetch with cache awareness.
  /// Returns cached data if valid, otherwise fetches from backend.
  static Future<List<GmailNotificationPreview>> smartFetch() async {
    // Try cache first
    final cached = await GmailCacheService.getCachedNotifications();
    if (cached != null) {
      print('[SMART_GMAIL] Using cached data (${cached.length} items)');
      return cached;
    }

    // Cache miss - fetch from backend
    print('[SMART_GMAIL] Cache miss - fetching fresh data');
    return await BackendService.fetchGmailNotificationPreviewsSmart();
  }

  /// Force refresh (user-initiated pull-to-refresh).
  /// Clears cache and fetches fresh data from backend.
  static Future<List<GmailNotificationPreview>> forceRefresh() async {
    await GmailCacheService.clearCache();
    return await BackendService.fetchGmailNotificationPreviewsSmart();
  }
}
