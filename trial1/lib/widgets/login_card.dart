import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class LoginRegisterCard extends StatefulWidget {
  const LoginRegisterCard({super.key});

  @override
  State<LoginRegisterCard> createState() => _LoginRegisterCardState();
}

class _LoginRegisterCardState extends State<LoginRegisterCard> {
  bool isLogin = true;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      padding: const EdgeInsets.all(24),
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFFC8C8C8), // Light gray card (matches mockup)
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          // -----------------------------------------------
          // CARD TITLE
          // -----------------------------------------------
          Text(
            isLogin ? "Welcome Back!" : "Create an Account",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 16),

          // -----------------------------------------------
          // TOP TABS
          // -----------------------------------------------
          Row(
            children: [
              _buildTab("Login", isActive: isLogin, onTap: () {
                setState(() => isLogin = true);
              }),
              const SizedBox(width: 12),
              _buildTab("Register", isActive: !isLogin, onTap: () {
                setState(() => isLogin = false);
              }),
            ],
          ),

          const SizedBox(height: 20),

          // -----------------------------------------------
          // FORM
          // -----------------------------------------------
          _buildInputField(
            controller: usernameController,
            hint: "Username",
          ),

          const SizedBox(height: 16),

          _buildInputField(
            controller: passwordController,
            hint: "Password",
            obscure: true,
          ),

          const SizedBox(height: 16),

          // Confirm Password (only in register mode)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: isLogin
                ? const SizedBox(key: ValueKey("empty"), height: 0)
                : _buildInputField(
                    controller: confirmPasswordController,
                    hint: "Confirm Password",
                    obscure: true,
                    key: const ValueKey("confirm"),
                  ),
          ),

          const SizedBox(height: 22),

          // -----------------------------------------------
          // OTHER OPTIONS TEXT
          // -----------------------------------------------
          const SizedBox(height: 8),
          Center(
            child: Text(
              "Sign in via other options",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 10),
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                // TODO: Implement Google sign-in
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Google sign-in pressed")),
                );
              },
              child: Container(
                width: 260,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  isDark
                    ? 'assets/signin-assets/Android/png@1x/dark/android_dark_rd_ctn@1x.png'
                    : 'assets/signin-assets/Android/png@1x/light/android_light_rd_ctn@1x.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),
          // -----------------------------------------------
          // ACTION BUTTON
          // -----------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE59A23), // orange
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 3,
              ),
              onPressed: () {
                if (isLogin) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                } else {
                  if (passwordController.text ==
                      confirmPasswordController.text) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Passwords do not match")),
                    );
                  }
                }
              },
              child: Text(
                isLogin ? "Login" : "Register",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // SizedBox(
          //   width: double.infinity,
          //   height: 48,
          //   child: OutlinedButton.icon(
          //     style: OutlinedButton.styleFrom(
          //       backgroundColor: const Color(0xFF3A3A3A),
          //       foregroundColor: Colors.white,
          //       side: const BorderSide(color: Color(0xFFE59A23), width: 1.5),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(26),
          //       ),
          //     ),
          //     icon: Icon(Icons.login, color: Colors.white), // Or use an asset/logo
          //     label: const Text(
          //       "Sign in with Google",
          //       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          //     ),
          //     onPressed: () {
          //       // TODO: Implement Google sign-in logic
          //       ScaffoldMessenger.of(context).showSnackBar(
          //         const SnackBar(content: Text("Google sign-in pressed")),
          //       );
          //     },
          //   ),
          // ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------
  // CUSTOM INPUT FIELD (matches your mockup)
  // ------------------------------------------------------
  Widget _buildInputField({
    Key? key,
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
  }) {
    return Container(
      key: key,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF3A3A3A), // dark gray mockup color
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------
  // TAB WIDGET (active → orange, inactive → dark gray)
  // ------------------------------------------------------
  Widget _buildTab(String text,
      {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFE59A23)
              : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
