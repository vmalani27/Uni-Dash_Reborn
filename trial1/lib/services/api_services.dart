import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trial1/config.dart';
import 'package:trial1/services/gmail_cache_service.dart';
import 'package:trial1/widgets/gmail_notifications_button.dart';
// Removed flutter_appauth import

class BackendService {
  // Get current user UID
  static Future<String> getCurrentUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    return user.uid;
  }

  // Fetch Gmail sync status
  static Future<String> fetchGmailSyncStatus(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$baseUrl/gmail/sync/status/$uid"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] as String;
    } else if (response.statusCode == 404) {
      return 'no_status';
    } else {
      throw Exception("Failed to fetch Gmail sync status: ${response.body}");
    }
  }

  // Trigger Gmail sync
  static Future<void> triggerGmailSync(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/gmail/sync/$uid"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to trigger Gmail sync: ${response.body}");
    }
  }

  static String get baseUrl => AppConfig.backendUrl;

  static final String webClientId = dotenv.env['oauth2_client_id_web']!;

  // Fetch Gmail notification previews (list-all)
  static Future<List<dynamic>> fetchGmailNotificationPreviews() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$baseUrl/notifications/gmail/list-all"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['notifications'] as List<dynamic>;
    } else {
      throw Exception(
        "Failed to fetch Gmail notification previews: ${response.body}",
      );
    }
  }

  // Fetch full Gmail message detail (get-mail)
  static Future<Map<String, dynamic>> fetchGmailMessageDetail(
    String gmailId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$baseUrl/notifications/gmail/get-mail/$gmailId"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to fetch Gmail message detail: ${response.body}");
    }
  }

  // Smart fetch with caching
  static Future<List<GmailNotificationPreview>>
  fetchGmailNotificationPreviewsSmart() async {
    // First try cache
    final cached = await GmailCacheService.getCachedNotifications();
    if (cached != null) {
      print('[API] Using cached notifications (${cached.length} items)');
      return cached;
    }

    // Cache miss - fetch from backend
    print('[API] Cache miss - fetching from backend');
    final rawList = await fetchGmailNotificationPreviews();
    final notifications = rawList
        .map<GmailNotificationPreview>(
          (n) => GmailNotificationPreview.fromJson(n as Map<String, dynamic>),
        )
        .toList();

    // Cache the results
    await GmailCacheService.cacheNotifications(notifications);
    return notifications;
  }

  // Trigger incremental sync
  static Future<void> triggerIncrementalSync(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/gmail/sync/$uid/incremental"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to trigger incremental sync: ${response.body}");
    }
  }

  // Get sync statistics
  static Future<Map<String, dynamic>> getGmailSyncStats(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$baseUrl/gmail/sync/stats/$uid"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch sync stats: ${response.body}");
    }
  }

  /* =======================
     USER PROFILE
     ======================= */

  static Future<Map<String, dynamic>> fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");

    final idToken = await user.getIdToken();

    try {
      final response = await http
          .get(
            Uri.parse("$baseUrl/user/profile"),
            headers: {"Authorization": "Bearer $idToken"},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception("Unauthorized. Please log in again.");
      } else {
        throw Exception(
          "Backend error: ${response.statusCode} ${response.body}",
        );
      }
    } on TimeoutException {
      throw Exception("Request timed out.");
    }
  }

  static Future<Map<String, dynamic>> createUserProfile({
    required String name,
    required String branch,
    required String semester,
    required String sid,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");

    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse("$baseUrl/user/profile-setup"),
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "name": name,
        "branch": branch,
        "semester": semester,
        "sid": sid,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Profile setup failed: ${response.body}");
    }
  }

  /* =======================
     GOOGLE OAUTH (CLIENT)
     ======================= */

  // Removed FlutterAppAuth instance

  static Future<void> startGoogleOAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");

    final idToken = await user.getIdToken();

    final response = await http.get(
      Uri.parse("$baseUrl/auth/google/url"),
      headers: {"Authorization": "Bearer $idToken"},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to get Google OAuth URL");
    }

    final data = jsonDecode(response.body);
    final authUrl = data["auth_url"];

    final uri = Uri.parse(authUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch Google OAuth");
    }
  }

  /* =======================
     GOOGLE OAUTH (BACKEND)
     ======================= */
  static Future<void> exchangeAuthCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");

    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse("$baseUrl/auth/google/exchange"),
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"code": code}),
    );

    if (response.statusCode == 200) {
      debugPrint("Google OAuth connected successfully");
    } else {
      debugPrint("OAuth exchange failed: ${response.body}");
    }
  }

  /* =======================
     LOGOUT
     ======================= */
  static Future<void> logout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");

    final idToken = await user.getIdToken();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/user/logout"),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode != 200) {
        debugPrint("Backend logout warning: ${response.body}");
        // Continue with client-side logout even if backend fails
      }
    } catch (e) {
      debugPrint("Backend logout error: $e");
      // Continue with client-side logout even if backend fails
    }
  }
}
