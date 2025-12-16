import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trial1/screens/login_screen.dart';
import 'package:trial1/screens/home_screen.dart';
import 'package:trial1/screens/profile_setup_screen.dart';
import 'package:trial1/services/api_services.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // loading firebase
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // user not logged in
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // user logged in → call backend
        return FutureBuilder(
          future: BackendService.fetchUserProfile(),
          builder: (context, profileSnapshot) {

            if (!profileSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

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
