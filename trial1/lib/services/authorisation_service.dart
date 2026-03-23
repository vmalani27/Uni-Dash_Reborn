import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trial1/screens/entry/intro_screen.dart';
import 'package:trial1/screens/home_screen.dart';
import 'package:trial1/screens/profile_setup_screen.dart';
import 'package:trial1/services/api_services.dart';

class AuthGate extends StatelessWidget {
  final VoidCallback? themeToggle;
  final ThemeMode? themeMode;
  const AuthGate({super.key, this.themeToggle, this.themeMode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final colorScheme = Theme.of(context).colorScheme;
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            ),
          );
        }
        if (!authSnapshot.hasData) {
          return const IntroScreen();
        }
        // Authenticated, fetch profile
        return FutureBuilder<Map<String, dynamic>>(
          future: BackendService.fetchUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: colorScheme.surface,
                body: Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              );
            }
            if (profileSnapshot.hasError) {
              return Scaffold(
                backgroundColor: colorScheme.surface,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.error,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load profile',
                        style: TextStyle(color: colorScheme.error, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!profileSnapshot.hasData) {
              return Scaffold(
                backgroundColor: colorScheme.surface,
                body: Center(
                  child: Text(
                    'No profile found',
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ),
              );
            }
            final profile = profileSnapshot.data!;
            final completed = profile["profile_completed"] ?? false;
            return completed
                ? HomeScreen(themeToggle: themeToggle, themeMode: themeMode)
                : ProfileSetupScreen(themeToggle: themeToggle, themeMode: themeMode);
          },
        );
      },
    );
  }
}
