import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trial1/config.dart';
import 'package:trial1/models/gmail_models.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/services/gmail_cache_service.dart';
// Removed flutter_appauth import

class BackendService {
    static Future<Map<String, dynamic>> updateUserProfile({
      required String? branch,
      required int? admissionYear,
    }) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("No Firebase user");

      final idToken = await user.getIdToken();

      // Build payload with only provided fields
      final Map<String, dynamic> payload = {};
      if (branch != null) {
        payload['branch'] = branch;
      }
      if (admissionYear != null) {
        payload['admission_year'] = admissionYear;
      }

      if (payload.isEmpty) {
        throw Exception("No fields to update");
      }

      final response = await http.patch(
        Uri.parse("$baseUrl/user/profile-setup"),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Profile update failed: ${response.body}");
      }
    }
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
      Uri.parse("$baseUrl/gmail/sync/status"),
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

  static String get baseUrl => AppConfig.backendUrl;

  static final String webClientId = dotenv.env['oauth2_client_id_web']!;

  static Future<dynamic> _getIdToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    return user.getIdToken(forceRefresh);
  }

  static bool _looksLikeTokenSkewError(String body) {
    final lower = body.toLowerCase();
    return lower.contains("token not yet valid") ||
        lower.contains("used too early") ||
        lower.contains("invalid or expired token");
  }

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
      Uri.parse("$baseUrl/gmail/sync/incremental"),
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
      Uri.parse("$baseUrl/gmail/sync/stats"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch sync stats: ${response.body}");
    }
  }

  /* =======================
     ACADEMIC DASHBOARD
     ======================= */

  static Future<List<AcademicItem>> fetchAcademicDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$baseUrl/notifications/academic/dashboard"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final items = data['academic_items'] as List<dynamic>;
      return items
          .map((e) => AcademicItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception("Failed to fetch academic dashboard: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> fetchUnifiedDashboard() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$baseUrl/api/dashboard/"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed to fetch unified dashboard: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> createManualAcademicEntity({
    required String canonicalTitle,
    required String entityType,
    String? summary,
    DateTime? bestDeadline,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/entities/manual"),
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({
        "canonical_title": canonicalTitle,
        "entity_type": entityType,
        "summary": summary,
        "best_deadline": bestDeadline?.toUtc().toIso8601String(),
        "confidence_score": 0.0,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception("Failed to create manual academic entity: ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchManualAcademicEntities() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse("$baseUrl/entities/manual"),
      headers: {"Authorization": "Bearer $idToken"},
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to fetch manual academic entities: ${response.body}");
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const <dynamic>[]);
  }

  static Future<Map<String, dynamic>> updateManualAcademicEntity({
    required int entityId,
    String? canonicalTitle,
    String? entityType,
    String? summary,
    DateTime? bestDeadline,
    double? confidenceScore,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.patch(
      Uri.parse("$baseUrl/entities/manual/$entityId"),
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({
        if (canonicalTitle != null) "canonical_title": canonicalTitle,
        if (entityType != null) "entity_type": entityType,
        if (summary != null) "summary": summary,
        if (bestDeadline != null) "best_deadline": bestDeadline.toUtc().toIso8601String(),
        if (confidenceScore != null) "confidence_score": confidenceScore,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to update manual academic entity: ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> deleteManualAcademicEntity(int entityId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.delete(
      Uri.parse("$baseUrl/entities/manual/$entityId"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to delete manual academic entity: ${response.body}");
    }
  }

  // Mark an academic item as completed
  static Future<void> markAcademicItemDone(int itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/items/$itemId/complete"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to mark academic item done: ${response.body}");
    }
  }

  // Add an academic item to Google Calendar
  static Future<void> addAcademicItemToCalendar(int itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/notifications/academic/$itemId/add-to-calendar"),
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({"hours": 24}),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to add item to calendar: ${response.body}");
    }
  }

  // Dismiss an academic item (remove from dashboard)
  static Future<void> dismissAcademicItem(int itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/items/$itemId/dismiss"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to dismiss academic item: ${response.body}");
    }
  }

  /* =======================
     USER PROFILE
     ======================= */

  static Future<Map<String, dynamic>> fetchUserProfile() async {
    Future<http.Response> doRequest({required bool forceRefresh}) async {
      final idToken = await _getIdToken(forceRefresh: forceRefresh);
      return http
          .get(
            Uri.parse("$baseUrl/user/profile"),
            headers: {"Authorization": "Bearer $idToken"},
          )
          .timeout(const Duration(seconds: 10));
    }

    try {
      var response = await doRequest(forceRefresh: false);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      if (response.statusCode == 401 && _looksLikeTokenSkewError(response.body)) {
        await Future.delayed(const Duration(milliseconds: 600));
        response = await doRequest(forceRefresh: true);
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      }

      if (response.statusCode == 401) {
        throw Exception("Unauthorized. Please log in again.");
      }

      throw Exception("Backend error: ${response.statusCode} ${response.body}");
    } on TimeoutException {
      throw Exception("Request timed out.");
    }
  }

  // Fetch service health summary (uses backend /health endpoint)
  static Future<Map<String, dynamic>> fetchHealth() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = user != null ? await user.getIdToken() : null;
    final response = await http
        .get(
          Uri.parse("$baseUrl/health"),
          headers: idToken != null ? {"Authorization": "Bearer $idToken"} : {},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch health: ${response.body}');
  }

  // Fetch user-scoped OAuth + sync state (suitable for user profile UI)
  static Future<Map<String, dynamic>> fetchUserOAuthStatus() async {
    final idToken = await _getIdToken();
    final response = await http
        .get(
          Uri.parse("$baseUrl/user/oauth/status"),
          headers: {"Authorization": "Bearer $idToken"},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401 && _looksLikeTokenSkewError(response.body)) {
      final refreshed = await http
          .get(
            Uri.parse("$baseUrl/user/oauth/status"),
            headers: {"Authorization": "Bearer ${await _getIdToken(forceRefresh: true)}"},
          )
          .timeout(const Duration(seconds: 8));
      if (refreshed.statusCode == 200) {
        return jsonDecode(refreshed.body) as Map<String, dynamic>;
      }
    }

    throw Exception('Failed to fetch user oauth status: ${response.body}');
  }

  static Future<Map<String, dynamic>> createUserProfile({
    required String fullName,
    required String degree,
    required String branch,
    required int admissionYear,
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
        "full_name": fullName,
        "degree": degree,
        "branch": branch,
        "admission_year": admissionYear,
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

    // On web, callback must return to an HTTPS/HTTP URL, not a custom app scheme.
    final oauthUrl = kIsWeb
        ? Uri.parse(
            "$baseUrl/auth/google/url",
          ).replace(queryParameters: {"redirect_to": "${Uri.base.origin}/#/"})
        : Uri.parse("$baseUrl/auth/google/url");

    final response = await http.get(
      oauthUrl,
      headers: {"Authorization": "Bearer $idToken"},
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to get Google OAuth URL");
    }

    final data = jsonDecode(response.body);
    final authUrl = data["auth_url"];

    final uri = Uri.parse(authUrl);
    final launched = kIsWeb
        ? await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_self',
          )
        : await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      throw Exception("Could not launch Google OAuth");
    }
  }

  static Future<Map<String, dynamic>> disconnectGoogleOAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");

    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/auth/google/disconnect"),
      headers: {"Authorization": "Bearer $idToken"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception("Failed to disconnect Google account: ${response.body}");
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
        // Backend logout failed, continuing with client-side logout
      }
    } catch (e) {
      // Backend logout error, continuing with client-side logout
    }

    await FirebaseAuth.instance.signOut();
  }
}

