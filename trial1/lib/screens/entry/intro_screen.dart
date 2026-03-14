import 'package:flutter/material.dart';
import '../../theme.dart';
import 'widgets/branding_section.dart';
import 'widgets/auth_card.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    return Scaffold(
      backgroundColor: kBgPrimary,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Branding/Intro (left)
                    const Expanded(child: BrandingSection()),
                    // Auth Card (right, anchored to top)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 120),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: const AuthCard(),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const BrandingSection(),
                        const SizedBox(height: 32),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: const AuthCard(),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}


