import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trial1/firebase_options.dart';
import 'package:trial1/app_container.dart';
import 'package:trial1/design/design_tokens.dart';
import 'package:trial1/services/oauth_callback_handler.dart';
import 'package:trial1/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: "assets/env_config");

  // Single web-first path for all platforms
  final backendUrl = AppConfig.getBackendUrl(dotenv.env);
  AppConfig.initialize(backendUrl);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _oauthHandler = OAuthCallbackHandler();

  @override
  void initState() {
    super.initState();
    _oauthHandler.init();
  }

  @override
  void dispose() {
    _oauthHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notify_Sphere',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      navigatorKey: _oauthHandler.navigatorKey,
      home: AppContainer(
        oauthHandler: _oauthHandler,
      ),
    );
  }
}

