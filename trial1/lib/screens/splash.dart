import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    // Fade-in animation for the logo
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

    // Navigate after delay (you'll redirect to login later)
    Future.delayed(const Duration(seconds: 3), () {
      // Navigator.pushReplacement(... your Login screen ...)
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;

    // Auto-select logo based on light/dark mode
    final logoPath = brightness == Brightness.dark
        ? "assets/university/dark_mode.png"
        : "assets/university/light_mode.png";

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                logoPath,
                width: 130,
                height: 130,
              ),

              const SizedBox(height: 25),

              // App Title
              Text(
                "Uni-Dash",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              // Subtitle
              Text(
                "Your smart academic dashboard",
                style: TextStyle(
                  fontSize: 14,
                  color: brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[700],
                ),
              ),

              const SizedBox(height: 30),

              // Loading Indicator
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(
                    brightness == Brightness.dark
                        ? Colors.white
                        : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
