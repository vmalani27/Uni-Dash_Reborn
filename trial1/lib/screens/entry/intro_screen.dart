import 'package:flutter/material.dart';
import 'widgets/branding_section.dart';
import 'widgets/auth_card.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          // ── DESKTOP ──────────────────────────────────────────────
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: BrandingSection(),
                          ),
                        ),
                        const SizedBox(width: 60),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 48),
                            child: AuthCard(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const _IntroFooter(),
            ],
          );
        }

        // ── MOBILE ───────────────────────────────────────────────
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const BrandingSection(),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: const AuthCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const _IntroFooter(), // ← always visible, never scrolls away
          ],
        );
      }),
    );
  }
}

class _IntroFooter extends StatelessWidget {
  const _IntroFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        '© 2026 Uni-Dash. All rights reserved.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}