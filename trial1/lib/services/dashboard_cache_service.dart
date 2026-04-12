import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardCacheService {
  static const String _dashboardKey = 'dashboard_snapshot_v1';
  static const String _timestampKey = 'dashboard_snapshot_ts_v1';

  static Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(snapshot);
    await prefs.setString(_dashboardKey, payload);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dashboardKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      await clearSnapshot();
    }
    return null;
  }

  static Future<int?> snapshotTimestampMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_timestampKey);
  }

  static Future<void> clearSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dashboardKey);
    await prefs.remove(_timestampKey);
  }
}
