import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:trial1/screens/home_screen.dart';
import 'package:trial1/screens/entry/intro_screen.dart';
import 'package:trial1/services/oauth_callback_handler.dart';

enum AppView { auth, dashboard }

class AppContainer extends StatefulWidget {
  final OAuthCallbackHandler oauthHandler;

  const AppContainer({
    super.key,
    required this.oauthHandler,
  });

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  AppView _currentView = FirebaseAuth.instance.currentUser == null
      ? AppView.auth
      : AppView.dashboard;
  int _oauthRefreshToken = 0;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    widget.oauthHandler.oauthSuccessTick.addListener(_onOAuthConnected);
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen(_onAuthStateChanged);
  }

  @override
  void dispose() {
    widget.oauthHandler.oauthSuccessTick.removeListener(_onOAuthConnected);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onOAuthConnected() {
    if (!mounted) {
      return;
    }
    setState(() {
      _oauthRefreshToken += 1;
    });
    _navigate(AppView.dashboard);
  }

  void _onAuthStateChanged(User? user) {
    if (!mounted) {
      return;
    }
    _navigate(user == null ? AppView.auth : AppView.dashboard);
  }

  void _navigate(AppView view) {
    setState(() => _currentView = view);
  }

  @override
  Widget build(BuildContext context) {
    // Auth gate determines initial view
    if (_currentView == AppView.auth) {
      return IntroScreen(
        onAuthSuccess: () => _navigate(AppView.dashboard),
      );
    }

    return _buildView();
  }

  Widget _buildView() {
    return switch (_currentView) {
      AppView.dashboard => HomeScreen(oauthRefreshToken: _oauthRefreshToken),
      AppView.auth => const SizedBox.shrink(), // Handled above
    };
  }
}
