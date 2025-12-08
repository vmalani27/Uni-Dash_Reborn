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
    return Container(
      margin: const EdgeInsets.only(bottom: 60),
      padding: const EdgeInsets.all(24),
      width: 340,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // -----------------------------------
          // TOP-LEFT TABS
          // -----------------------------------
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

          const SizedBox(height: 16),

          // -----------------------------------
          // FORM CONTENT
          // -----------------------------------
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Username
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  hintText: "Username",
                  filled: true,
                  fillColor: Colors.grey[500],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Password",
                  filled: true,
                  fillColor: Colors.grey[500],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ⭐ Fade-in Confirm Password field — same space reserved ⭐
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isLogin
                    ? SizedBox(
                        key: const ValueKey("empty-space"),
                        height: 0,
                      )
                    : SizedBox(
                        key: const ValueKey("confirm-field"),
                        height: 55,
                        child: TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: "Confirm Password",
                            filled: true,
                            fillColor: Colors.grey[500],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // -----------------------------------
          // ACTION BUTTON AT BOTTOM
          // -----------------------------------
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
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
              child: Text(isLogin ? "Login" : "Register"),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------
  // TAB WIDGET (TOP LEFT)
  // -----------------------------------
  Widget _buildTab(String text,
      {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey[600],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
