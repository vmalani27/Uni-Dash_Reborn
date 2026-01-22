import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:trial1/firebase_options.dart';
import 'theme.dart';
import 'package:trial1/services/authorisation_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'config.dart';

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  await dotenv.load(fileName: ".env");
  
  // Source - https://stackoverflow.com/a/63131245
  // Posted by Matias de Andrea
  // Retrieved 2026-01-22, License - CC BY-SA 4.0

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String backendUrl = dotenv.env['BACKEND_URL']!;
  
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    print('Is physical device: ${androidInfo.isPhysicalDevice}');

    if(!androidInfo.isPhysicalDevice) {
      print('Running on an emulator - using EMULATOR_BACKEND_URL');
      backendUrl = dotenv.env['EMULATOR_BACKEND_URL'] ?? backendUrl;
      print('Backend URL: $backendUrl');
    } else {
      print('Running on a physical device - using BACKEND_URL');
      print('Backend URL: $backendUrl');
    }
  } else if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    print('Is physical device: ${iosInfo.isPhysicalDevice}');
    
    if(!iosInfo.isPhysicalDevice) {
      print('Running on a simulator - using EMULATOR_BACKEND_URL');
      backendUrl = dotenv.env['EMULATOR_BACKEND_URL'] ?? backendUrl;
      print('Backend URL: $backendUrl');
    } else {
      print('Running on a physical device - using BACKEND_URL');
      print('Backend URL: $backendUrl');
    }
  }
  
  // Initialize global config
  AppConfig.initialize(backendUrl);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notify Sphere',
      theme: uniDashLightTheme,
      darkTheme: uniDashDarkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
