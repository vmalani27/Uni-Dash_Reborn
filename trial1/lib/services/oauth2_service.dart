import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'api_services.dart';

class OAuthHandler extends StatefulWidget {
  final Widget child;
  const OAuthHandler({super.key, required this.child});

  @override
  State<OAuthHandler> createState() => _OAuthHandlerState();
}

class _OAuthHandlerState extends State<OAuthHandler> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();

    _appLinks = AppLinks();

    // Handle cold start (app launched via OAuth redirect)
    _appLinks.getInitialLink().then((uri) {
      debugPrint('[OAuthHandler] getInitialLink fired: $uri');
      if (uri != null) {
        _handleUri(uri);
      }
    });

    // Handle foreground / background redirects
    _sub = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[OAuthHandler] uriLinkStream fired: $uri');
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    debugPrint("Received deep link: $uri");

    // Safety check: only handle our OAuth redirect
    if (uri.scheme != "com.example.trial1" ||
        uri.host != "oauth2redirect") {
      return;
    }

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    if (code != null) {
      BackendService.exchangeAuthCode(code);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
