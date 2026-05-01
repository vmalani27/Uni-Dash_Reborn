import 'package:flutter/material.dart';
import 'package:trial1/services/api_services.dart';

class ConnectGmailScreen extends StatefulWidget {
  final VoidCallback? onSkip;
  final VoidCallback? onConnected;
  final bool allowSkip;

  const ConnectGmailScreen({
    super.key,
    this.onSkip,
    this.onConnected,
    this.allowSkip = true,
  });

  @override
  State<ConnectGmailScreen> createState() => _ConnectGmailScreenState();
}

class _ConnectGmailScreenState extends State<ConnectGmailScreen> {
  bool _isConnecting = false;

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await BackendService.startGoogleOAuth();
      if (mounted) {
        widget.onConnected?.call();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect Gmail: $e')),
      );
    }
  }

  void _skip() {
    widget.onSkip?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;
                  final left = _buildEditorialHero(context);
                  final right = _buildActionPanel(context);
                  final topBar = Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Setup',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isWide) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          topBar,
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 58, child: left),
                                const SizedBox(width: 32),
                                Expanded(flex: 42, child: right),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        topBar,
                        const SizedBox(height: 18),
                        left,
                        const SizedBox(height: 20),
                        right,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialHero(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inbox',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.58),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Connect your inbox',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              'Notify Sphere scans for assignments, deadlines, announcements, and course updates once Gmail is linked.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connect inbox',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This only takes a moment, and you can manage it later from Profile.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.70),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isConnecting ? null : _connect,
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isConnecting
                    ? colorScheme.onSurface.withValues(alpha: 0.25)
                    : colorScheme.onSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isConnecting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.surface,
                      ),
                    )
                  : Text(
                      'Continue',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (widget.allowSkip && widget.onSkip != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _skip,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    'Skip for now',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
