import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trial1/models/gmail_models.dart';

class GmailCacheService {
  static const String _cacheKey = 'gmail_notifications';
  static const String _cacheTimestampKey = '${_cacheKey}_timestamp';
  static const String _lastSyncKey = 'gmail_last_sync';
  static const Duration _cacheExpiry = Duration(minutes: 15);

  /// Get cached notifications if they're still fresh
  static Future<List<GmailNotificationPreview>?>
  getCachedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_cacheTimestampKey);

    if (cached != null && timestamp != null) {
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (cacheAge < _cacheExpiry.inMilliseconds) {
        try {
          final List<dynamic> jsonList = jsonDecode(cached);
          return jsonList
              .map((e) => GmailNotificationPreview.fromJson(e))
              .toList();
        } catch (e) {
          print('[CACHE] Error parsing cached notifications: $e');
          await clearCache(); // Clear corrupt cache
        }
      }
    }
    return null;
  }

  /// Cache notifications with timestamp
  static Future<void> cacheNotifications(
    List<GmailNotificationPreview> notifications,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final jsonString = jsonEncode(
        notifications
            .map(
              (n) => {
                'id': n.id,
                'gmail_id': n.gmailId,
                'sender': n.sender,
                'subject': n.subject,
                'snippet': n.snippet,
                'internal_date': n.internalDate?.toIso8601String(),
                'deadline_iso': n.deadlineIso?.toIso8601String(),
                'deadline_confidence': n.deadlineConfidence,
                'academic_score': n.academicScore,
                'normalized_topic': n.normalizedTopic,
              },
            )
            .toList(),
      );

      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('[CACHE] Cached ${notifications.length} notifications');
    } catch (e) {
      print('[CACHE] Error caching notifications: $e');
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
    print('[CACHE] Cache cleared');
  }

  /// Check if cache is still valid
  static Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_cacheTimestampKey);
    if (timestamp == null) return false;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
    return cacheAge < _cacheExpiry.inMilliseconds;
  }

  /// Track last manual sync time to prevent excessive syncing
  static Future<void> updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<DateTime> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}
