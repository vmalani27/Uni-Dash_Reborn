import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/services/gmail_cache_service.dart';
import 'package:trial1/widgets/gmail_notifications_button.dart';

class SmartGmailService {
  static Timer? _refreshTimer;
  static Timer? _backgroundSyncTimer;
  static bool _isAppActive = true;

  /// Start smart refresh when app becomes active
  static void startPeriodicRefresh() {
    stopPeriodicRefresh(); // Clean up existing timers

    // Lightweight check every 5 minutes when app is active
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isAppActive) {
        _checkForNewEmails();
      }
    });

    // Background sync every 15 minutes (when app is backgrounded)
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      if (!_isAppActive) {
        _backgroundSync();
      }
    });

    print('[SMART_GMAIL] Periodic refresh started');
  }

  static void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _backgroundSyncTimer?.cancel();
    _refreshTimer = null;
    _backgroundSyncTimer = null;
    print('[SMART_GMAIL] Periodic refresh stopped');
  }

  static void setAppActive(bool active) {
    _isAppActive = active;
    print('[SMART_GMAIL] App active: $active');
  }

  /// Check for new emails (foreground mode)
  static Future<void> _checkForNewEmails() async {
    try {
      // Only sync if user hasn't manually synced recently
      final lastManualSync = await GmailCacheService.getLastSyncTime();
      final timeSinceManualSync = DateTime.now().difference(lastManualSync);

      if (timeSinceManualSync.inMinutes < 3) {
        print('[SMART_GMAIL] Skipping auto-sync - recent manual sync');
        return; // Skip if recent manual sync
      }

      // Check if cache is still valid
      if (await GmailCacheService.isCacheValid()) {
        print('[SMART_GMAIL] Cache still valid, skipping sync');
        return;
      }

      // Trigger lightweight incremental sync
      final uid = await BackendService.getCurrentUid();
      print('[SMART_GMAIL] Triggering auto incremental sync');
      await BackendService.triggerIncrementalSync(uid);

      // Wait for sync to potentially complete
      await Future.delayed(const Duration(seconds: 2));

      // Clear cache to force fresh fetch on next UI load
      await GmailCacheService.clearCache();
      print('[SMART_GMAIL] Cache cleared after auto-sync');
    } catch (e) {
      print('[SMART_GMAIL] Auto-sync error: $e');
      // Don't throw - this is background operation
    }
  }

  /// Background sync (app backgrounded)
  static Future<void> _backgroundSync() async {
    try {
      if (!await _shouldBackgroundSync()) {
        return;
      }

      final uid = await BackendService.getCurrentUid();
      print('[SMART_GMAIL] Background sync triggered');
      await BackendService.triggerIncrementalSync(uid);

      // Wait for sync to complete
      await Future.delayed(const Duration(seconds: 2));

      // Clear cache so next app open gets fresh data
      await GmailCacheService.clearCache();
      print('[SMART_GMAIL] Cache cleared after background sync');
    } catch (e) {
      print('[SMART_GMAIL] Background sync error: $e');
    }
  }

  /// Determine if background sync is needed
  static Future<bool> _shouldBackgroundSync() async {
    try {
      // Check when last successful sync was
      final uid = await BackendService.getCurrentUid();
      final stats = await BackendService.getGmailSyncStats(uid);

      if (stats['last_sync_date'] == null) {
        return true; // Never synced
      }

      final lastSync = DateTime.parse(stats['last_sync_date']);
      final timeSinceSync = DateTime.now().difference(lastSync);

      // Background sync if no sync in last hour
      return timeSinceSync.inHours >= 1;
    } catch (e) {
      print('[SMART_GMAIL] Error checking sync status: $e');
      return false; // Don't sync if we can't determine status
    }
  }

  /// Force refresh (user-initiated)
  static Future<List<GmailNotificationPreview>> forceRefresh() async {
    print('[SMART_GMAIL] Force refresh triggered');

    // Clear cache first
    await GmailCacheService.clearCache();

    // Update last sync time to prevent auto-sync interference
    await GmailCacheService.updateLastSyncTime();

    // Trigger manual sync
    final uid = await BackendService.getCurrentUid();
    await BackendService.triggerGmailSync(uid);

    // Wait for completion and fetch
    return await _waitForSyncAndFetch(uid);
  }

  /// Smart fetch with cache awareness
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

  static Future<List<GmailNotificationPreview>> _waitForSyncAndFetch(
    String uid,
  ) async {
    // Poll for completion
    for (int i = 0; i < 40; i++) {
      // ~2 minutes max
      await Future.delayed(const Duration(seconds: 3));
      final status = await BackendService.fetchGmailSyncStatus(uid);

      if (status == 'completed') {
        // Fetch fresh data
        return await BackendService.fetchGmailNotificationPreviewsSmart();
      } else if (status == 'failed') {
        throw Exception('Gmail sync failed');
      }
    }

    throw Exception('Gmail sync timed out');
  }
}
