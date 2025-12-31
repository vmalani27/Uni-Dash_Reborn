import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

class BackendService {
  static final String baseUrl = dotenv.env['BACKEND_URL']!;
  static final String androidClientId =
      dotenv.env['ANDROID_GOOGLE_CLIENT_ID']!;

  static final String webClientId =
    dotenv.env['oauth2_client_id_web']!;


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

static final FlutterAppAuth _appAuth = FlutterAppAuth();


static Future<void> startGoogleOAuth() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception("No Firebase user");

final redirectUri =
  'com.googleusercontent.apps.551724754459-qa0mnvf692mj8s9gkmu6n7otjfslbtuo:/oauth2redirect';
final result = await _appAuth.authorize(
  AuthorizationRequest(
    androidClientId,
    redirectUri,
    discoveryUrl: 'https://accounts.google.com/.well-known/openid-configuration',
    scopes: [
      'openid',
      'email',
      'profile',

      'https://www.googleapis.com/auth/gmail.readonly',

      'https://www.googleapis.com/auth/classroom.courses.readonly',
      'https://www.googleapis.com/auth/classroom.announcements.readonly',
      'https://www.googleapis.com/auth/classroom.coursework.students.readonly',],
    additionalParameters: {
      'access_type': 'offline',
      
    },

    promptValues: const  ['consent'],
  ),

);

debugPrint("App Auth result: $result");
  if (result == null || result.authorizationCode == null) {
    throw Exception("OAuth failed");
  }

await exchangeAuthCode(
  result.authorizationCode!,
  result.codeVerifier!,
);
}



  /* =======================
     GOOGLE OAUTH (BACKEND)
     ======================= */
static Future<void> exchangeAuthCode(String code, String codeVerifier) async {
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
      "code_verifier": codeVerifier,
    }),
  );

  if (response.statusCode == 200) {
    debugPrint("Google OAuth connected successfully");
  } else {
    debugPrint("OAuth exchange failed: ${response.body}");
  }
}


}
