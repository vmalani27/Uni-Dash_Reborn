import 'package:flutter/material.dart';
import 'screens/splash.dart';
import 'theme.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uni-Dash Reborn',
      theme: uniDashLightTheme,
      darkTheme: uniDashDarkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
