import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../widgets/login_card.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  /// Simulated login state (temporary)
  final bool isLoggedIn = false;

  late AnimationController _logoController;
  late AnimationController _loginController;

  late Animation<Offset> _logoSlideUp;
  late Animation<double> _loginFadeIn;
  late Animation<Offset> _loginSlideUp;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: const Offset(0, -0.6),
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _loginController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _loginFadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _loginController, curve: Curves.easeIn),
    );

    _loginSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _loginController, curve: Curves.easeOut),
    );

    _runSplashFlow();
  }

  void _runSplashFlow() {
    Future.delayed(const Duration(seconds: 2), () {
      _logoController.forward();

      Future.delayed(const Duration(milliseconds: 600), () {
        if (isLoggedIn) {
          _navigateToHome();
        } else {
          _loginController.forward();
        }
      });
    });
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loginController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;

    final logoPath = brightness == Brightness.dark
        ? "assets/university/dark_mode.png"
        : "assets/university/light_mode.png";

    return Scaffold(
      backgroundColor:
          brightness == Brightness.dark ? Colors.black : Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: SlideTransition(
              position: _logoSlideUp,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(logoPath, width: 120, height: 120),
                  const SizedBox(height: 18),
                  Text(
                    "Uni-Dash",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isLoggedIn)
            FadeTransition(
              opacity: _loginFadeIn,
              child: SlideTransition(
                position: _loginSlideUp,
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: LoginRegisterCard(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
