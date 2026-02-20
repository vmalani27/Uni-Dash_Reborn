import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trial1/screens/entry/intro_screen.dart';
import 'package:trial1/screens/home_screen.dart';
import 'package:trial1/screens/profile_setup_screen.dart';
import 'package:trial1/services/api_services.dart';
import 'package:trial1/theme.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Firebase loading state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kBgPrimary,
            body: const Center(
              child: CircularProgressIndicator(color: kAccentPrimary),
            ),
          );
        }

        // User not authenticated → show IntroScreen
        if (!authSnapshot.hasData) {
          return const IntroScreen();
        }

        // User authenticated → fetch profile and route accordingly
        return FutureBuilder<Map<String, dynamic>>(
          future: BackendService.fetchUserProfile(),
          builder: (context, profileSnapshot) {
            // Profile loading state
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: kBgPrimary,
                body: const Center(
                  child: CircularProgressIndicator(color: kAccentPrimary),
                ),
              );
            }

            // Profile fetch error
            if (profileSnapshot.hasError) {
              return Scaffold(
                backgroundColor: kBgPrimary,
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load profile',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // Trigger rebuild by popping and pushing
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const AuthGate()),
                          );
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // No profile data
            if (!profileSnapshot.hasData) {
              return Scaffold(
                backgroundColor: kBgPrimary,
                body: const Center(
                  child: Text(
                    'No profile found',
                    style: TextStyle(color: kTextSecondary),
                  ),
                ),
              );
            }

            // Profile exists → route based on completion status
            final profile = profileSnapshot.data!;
            final completed = profile["profile_completed"] ?? false;

            if (!completed) {
              return const ProfileSetupScreen();
            }

            return const HomeScreen();
          },
        );
      },
    );
  }
}
