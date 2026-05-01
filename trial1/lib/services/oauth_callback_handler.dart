import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

class OAuthCallbackHandler {
  final navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> oauthSuccessTick = ValueNotifier<int>(0);
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void init() {
    _handleInitialUri();
    _handleIncomingLinks();
  }

  void dispose() {
    _linkSubscription?.cancel();
    oauthSuccessTick.dispose();
  }

  /// Handle deep link when app is cold-started
  Future<void> _handleInitialUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      print('[OAUTH] Error handling initial URI: $e');
    }
  }

  /// Handle deep links when app is already running
  void _handleIncomingLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (e) {
        print('[OAUTH] Error handling incoming link: $e');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    print('[OAUTH] Deep link received: $uri');

    // Handle OAuth success callback
    final isOAuthSuccess =
        // Preferred mobile callback: unidash://oauth/success
        (uri.scheme == 'unidash' && uri.host == 'oauth' && uri.path == '/success') ||
        // Legacy/alternate callback forms
        uri.path == '/oauth/success' ||
        uri.path == '/oauth-success';

    if (isOAuthSuccess) {
      _handleOAuthSuccess();
    }
  }

  Future<void> _handleOAuthSuccess() async {
    print('[OAUTH] OAuth success detected - triggering auto-sync');

    final context = navigatorKey.currentContext;
    if (context == null) {
      print('[OAUTH] No context available');
      return;
    }

    try {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gmail connected successfully! Syncing emails...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // No manual sync trigger needed — backend ingestion loop
      // will detect this user's OAuth token and start fetching
      // emails automatically within the next 3 minutes.
      print('[OAUTH] Gmail connected. Backend will sync automatically.');
      oauthSuccessTick.value = oauthSuccessTick.value + 1;
    } catch (e) {
      print('[OAUTH] Error handling OAuth success: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OAuth connected, but sync failed: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

