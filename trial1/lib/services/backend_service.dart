import 'dart:convert';
import 'package:trial1/services/api_client.dart';

/// Backend service layer
/// Pure business logic, no Firebase, no HTTP details
/// All HTTP is delegated to ApiClient
class BackendService {
  final ApiClient api;

  BackendService(this.api);

  /* ========================
     GMAIL NOTIFICATIONS
     ======================== */

  Future<List<dynamic>> fetchGmailNotificationPreviews() async {
    final response = await api.get("/notifications/gmail/list-all");
    return api.parseJson(response, (json) {
      return json['notifications'] as List<dynamic>;
    });
  }

  Future<Map<String, dynamic>> fetchGmailMessageDetail(String gmailId) async {
    final response = await api.get("/notifications/gmail/get-mail/$gmailId");
    return api.parseJson(response, (json) => json);
  }

  /* ========================
     GMAIL SYNC
     ======================== */

  Future<String> fetchGmailSyncStatus(String uid) async {
    try {
      final response = await api.get("/gmail/sync/status/$uid");
      return api.parseJson(response, (json) {
        return json['status'] as String;
      });
    } catch (e) {
      // Return 'no_status' if endpoint returns 404
      return 'no_status';
    }
  }

  Future<void> triggerGmailSync(String uid) async {
    final response = await api.post("/gmail/sync/$uid");
    api.parseJson(response, (json) => null);
  }

  /* ========================
     USER PROFILE
     ======================== */

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final response = await api.get("/user/profile");
    return api.parseJson(response, (json) => json);
  }

  Future<Map<String, dynamic>> createUserProfile({
    required String name,
    required String branch,
    required String semester,
    required String sid,
  }) async {
    final body = jsonEncode({
      "name": name,
      "branch": branch,
      "semester": semester,
      "sid": sid,
    });

    final response = await api.post("/user/profile-setup", body: body);
    return api.parseJson(response, (json) => json);
  }

  /* ========================
     GOOGLE OAUTH
     ======================== */

  Future<String> getGoogleOAuthUrl() async {
    final response = await api.get("/auth/google/url");
    return api.parseJson(response, (json) {
      return json["auth_url"] as String;
    });
  }

  Future<void> exchangeAuthCode(String code) async {
    final body = jsonEncode({"code": code});
    final response = await api.post("/auth/google/exchange", body: body);
    api.parseJson(response, (json) => null);
  }

  /* ========================
     LOGOUT
     ======================== */

  Future<void> logout() async {
    try {
      final response = await api.post("/user/logout");
      api.parseJson(response, (json) => null);
    } catch (e) {
      // Backend logout failure is not fatal
      rethrow;
    }
  }

  /* ========================
     AUTH UTILITIES
     ======================== */
