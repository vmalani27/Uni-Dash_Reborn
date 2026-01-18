import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
// Removed flutter_appauth import

class BackendService {
      static final String baseUrl = dotenv.env['BACKEND_URL']!;

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
        throw Exception("Failed to fetch Gmail notification previews: ${response.body}");
      }
    }

    // Fetch full Gmail message detail (get-mail)
    static Future<Map<String, dynamic>> fetchGmailMessageDetail(String gmailId) async {
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
    headers: {
      "Authorization": "Bearer $idToken",
    },
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
    body: jsonEncode({
      "code": code,
    }),
  );

  if (response.statusCode == 200) {
    debugPrint("Google OAuth connected successfully");
  } else {
    debugPrint("OAuth exchange failed: ${response.body}");
  }
}


}
