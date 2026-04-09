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

  // Trigger Gmail sync
  static Future<void> triggerGmailSync(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/gmail/sync"),
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

  // Mark an academic item as completed
  static Future<void> markAcademicItemDone(int itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/notifications/academic/$itemId/mark-done"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to mark academic item done: ${response.body}");
    }
  }

  // Mark an academic item as missed
  static Future<void> markAcademicItemMissed(int itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/notifications/academic/$itemId/mark-missed"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to mark academic item missed: ${response.body}");
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

  // Snooze an academic item for a period of time
  static Future<void> snoozeAcademicItem(int itemId, {int hours = 24}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/notifications/academic/$itemId/snooze"),
      headers: {
        "Authorization": "Bearer $idToken",
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({"hours": hours}),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to snooze academic item: ${response.body}");
    }
  }

  // Dismiss an academic item (remove from dashboard)
  static Future<void> dismissAcademicItem(int itemId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/notifications/academic/$itemId/dismiss"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to dismiss academic item: ${response.body}");
    }
  }

  static Future<void> dismissFollowUp(int followUpId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse("$baseUrl/notifications/gmail/follow-ups/$followUpId/dismiss"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to dismiss follow up: ${response.body}");
    }
  }

  /* =======================
     SEARCH
     ======================= */

  static Future<SearchResults> searchAcademicItems(String query) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    
    final response = await http.get(
      Uri.parse("$baseUrl/search/academic?q=${Uri.encodeComponent(query)}"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return SearchResults.fromJson(json);
    } else {
      throw Exception("Search failed: ${response.body}");
    }
  }

  static Future<List<String>> getSearchSuggestions(String query) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");
    final idToken = await user.getIdToken();
    
    final response = await http.get(
      Uri.parse("$baseUrl/search/academic/suggestions?q=${Uri.encodeComponent(query)}"),
      headers: {
        "Authorization": "Bearer $idToken",
        "ngrok-skip-browser-warning": "true",
      },
    );
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return List<String>.from(json['suggestions'] ?? []);
    } else {
      throw Exception("Suggestions failed: ${response.body}");
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No Firebase user");

    final idToken = await user.getIdToken();
    final response = await http
        .get(
          Uri.parse("$baseUrl/user/oauth/status"),
          headers: {"Authorization": "Bearer $idToken"},
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Failed to fetch user oauth status: ${response.body}');
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

/// Search results model
class SearchResults {
  final String query;
  final int total;
  final Map<String, List<SearchResultItem>> groups;

  SearchResults({
    required this.query,
    required this.total,
    required this.groups,
  });

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      query: json['query'] ?? '',
      total: json['total'] ?? 0,
      groups: {
        'today': _parseGroup(json['groups']?['today']),
        'tomorrow': _parseGroup(json['groups']?['tomorrow']),
        'thisWeek': _parseGroup(json['groups']?['thisWeek']),
        'others': _parseGroup(json['groups']?['others']),
      },
    );
  }

  static List<SearchResultItem> _parseGroup(dynamic data) {
    if (data == null) return [];
    return (data as List)
        .map((item) => SearchResultItem.fromJson(item))
        .toList();
  }
}

/// Individual search result item
class SearchResultItem {
  final int id;
  final String gmailId;
  final String subject;
  final String? summary;
  final String? category;
  final double score;

  SearchResultItem({
    required this.id,
    required this.gmailId,
    required this.subject,
    this.summary,
    this.category,
    required this.score,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      id: json['id'] ?? 0,
      gmailId: json['gmail_id'] ?? '',
      subject: json['subject'] ?? '',
      summary: json['summary'],
      category: json['category'],
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
