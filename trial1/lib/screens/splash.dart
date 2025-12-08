import 'package:flutter/material.dart';
import 'package:trial1/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoController;
  late Animation<Offset> _logoSlideUp;
  late Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    _logoSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: const Offset(0, -0.10),
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  void _startAnimation() {
    _logoController.forward();

    /// Navigate after animation completes
    Future.delayed(const Duration(milliseconds: 1800), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final logoPath = brightness == Brightness.dark
        ? "assets/university/dark_mode.png"
        : "assets/university/light_mode.png";

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _logoFade,
            child: SlideTransition(
              position: _logoSlideUp,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(logoPath, width: 120, height: 120),
                  const SizedBox(height: 14),
                  Text(
                    "Uni-Dash",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Unified Academic Dashboard",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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
