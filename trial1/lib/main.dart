import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trial1/firebase_options.dart';
import 'package:trial1/services/authorisation_service.dart';
import 'package:trial1/services/oauth_callback_handler.dart';
import 'theme.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NOTE: For Web, you must pass DefaultFirebaseOptions.currentPlatform
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: "assets/env_config");

  // Source - https://stackoverflow.com/a/63131245
  // Posted by Matias de Andrea
  // Retrieved 2026-01-22, License - CC BY-SA 4.0

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  
  String backendUrl;
  
  if (kIsWeb) {
    print('Running on Web - using BACKEND_URL');
    backendUrl = AppConfig.getBackendUrl(
      dotenv.env,
      isPhysicalDevice: true,
      isWeb: true,
    );
    print('Backend URL: $backendUrl');
  } else if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print('Is physical device: ${androidInfo.isPhysicalDevice}');

    backendUrl = AppConfig.getBackendUrl(
      dotenv.env,
      isPhysicalDevice: androidInfo.isPhysicalDevice,
      isWeb: false,
    );

    if (!androidInfo.isPhysicalDevice) {
      print('Running on an emulator - using EMULATOR_BACKEND_URL');
    } else {
      print('Running on a physical device - using BACKEND_URL');
    }
    print('Backend URL: $backendUrl');
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    print('Is physical device: ${iosInfo.isPhysicalDevice}');

    backendUrl = AppConfig.getBackendUrl(
      dotenv.env,
      isPhysicalDevice: iosInfo.isPhysicalDevice,
      isWeb: false,
    );

    if (!iosInfo.isPhysicalDevice) {
      print('Running on a simulator - using EMULATOR_BACKEND_URL');
    } else {
      print('Running on a physical device - using BACKEND_URL');
    }
    print('Backend URL: $backendUrl');
  } else {
    // Fallback for other platforms
    backendUrl = AppConfig.getBackendUrl(
      dotenv.env,
      isPhysicalDevice: true,
      isWeb: false,
    );
  }

  // Initialize global config
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
      title: 'Notify Sphere',
      theme: uniDashLightTheme,
      darkTheme: uniDashDarkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      navigatorKey: _oauthHandler.navigatorKey,
      home: const AuthGate(),
    );
  }
}
