import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:trial1/services/app_services.dart';
import 'package:trial1/screens/home_screen.dart';

class OAuthCallbackHandler {
  final navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void init() {
    _handleInitialUri();
    _handleIncomingLinks();
  }

  void dispose() {
    _linkSubscription?.cancel();
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
    if (uri.path == '/oauth/success' || uri.path == '/oauth-success') {
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

      // Get user ID and trigger initial sync
      final uid = await BackendService.getCurrentUid();

      // Trigger full sync in background (non-blocking)
      BackendService.triggerGmailSync(uid)
          .then((_) {
            print('[OAUTH] Initial sync triggered successfully');
          })
          .catchError((e) {
            print('[OAUTH] Sync trigger failed: $e');
          });

      // Navigate to root and let AuthGate determine the correct screen
      // This will refresh profile state and navigate appropriately
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
