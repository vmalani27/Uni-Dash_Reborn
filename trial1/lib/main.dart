// Add this import for dotenv
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:trial1/firebase_options.dart';
import 'package:trial1/services/oauth2_service.dart';
import 'theme.dart';
import 'package:trial1/services/authorisation_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  await dotenv.load(fileName: ".env");

  runApp(
    OAuthHandler(
      child: MyApp(),
    ),
  );
}
// Example usage of the client ID in your OAuth flow:
// final clientId = dotenv.env['ANDROID_GOOGLE_CLIENT_ID']!;
// Use clientId when building the Google OAuth URL.

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uni-Dash Reborn',
      theme: uniDashLightTheme,
      darkTheme: uniDashDarkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
