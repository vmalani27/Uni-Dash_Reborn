import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import 'package:trial1/services/auth_gate_service.dart';
import 'Password_field.dart';
import 'Username_field.dart';

class LoginRegisterCard extends StatefulWidget {
  const LoginRegisterCard({super.key});

  @override
  State<LoginRegisterCard> createState() => _LoginRegisterCardState();
}

class _LoginRegisterCardState extends State<LoginRegisterCard> {
  bool isLogin = true;

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool showConfirmField = false;
  bool passwordValid = false;
  String password = "";

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,

      child: Container(
        padding: const EdgeInsets.all(24),
        width: 340,
        decoration: BoxDecoration(
          color: const Color(0xFFC8C8C8),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // TITLE
            Text(
              isLogin ? "Welcome Back!" : "Create an Account",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 16),

            // TABS
            Row(
              children: [
                _buildTab("Login", isActive: isLogin, onTap: () {
                  setState(() {
                    isLogin = true;
                    showConfirmField = false;
                  });
                }),
                const SizedBox(width: 12),
                _buildTab("Register", isActive: !isLogin, onTap: () {
                  setState(() {
                    isLogin = false;
                    showConfirmField = false;
                  });
                }),
              ],
            ),

            const SizedBox(height: 20),

            // USERNAME
            UsernameField(controller: usernameController, hint: "Username"),
            const SizedBox(height: 16),

            // PASSWORD
            PasswordField(
              controller: passwordController,
              hint: "Password",
              onChanged: (value) {
                setState(() {
                  password = value;
                  passwordValid = validatePassword(value);

                  if (passwordValid && !showConfirmField && !isLogin) {
                    showConfirmField = true;
                  }
                });
              },
            ),

            const SizedBox(height: 12),

            // PASSWORD RULES
            if (!isLogin && !showConfirmField)
              _buildPasswordRules(),

            const SizedBox(height: 16),

            // CONFIRM PASSWORD
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: (!isLogin && showConfirmField)
                  ? PasswordField(
                      key: const ValueKey("confirmField"),
                      controller: confirmPasswordController,
                      hint: "Confirm Password",
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 22),

            // SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE59A23),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 3,
                ),
                child: Text(isLogin ? "Login" : "Register"),
              ),
            ),
          ],
        ),
      ),
    );
  }



Widget _buildPasswordRules() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _rule("At least 8 characters", password.length >= 8),
      _rule("One uppercase letter", password.contains(RegExp(r'[A-Z]'))),
      _rule("One number", password.contains(RegExp(r'[0-9]'))),
      _rule("One symbol", password.contains(RegExp(r'[!@#$%^&*(),.?\":{}|<>]'))),
    ],
  );
}

Widget _rule(String text, bool ok) {
  return Row(
    children: [
      Icon(ok ? Icons.check_circle : Icons.circle_outlined,
          size: 16, color: ok ? Colors.green : Colors.black54),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 12, color: ok ? Colors.green : Colors.black54)),
    ],
  );
}
Widget _buildTab(String text, {required bool isActive, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE59A23) : const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

bool validatePassword(String pass) {
  final hasMinLength = pass.length >= 8;
  final hasUpper = pass.contains(RegExp(r'[A-Z]'));
  final hasNumber = pass.contains(RegExp(r'[0-9]'));
  final hasSymbol = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  return hasMinLength && hasUpper && hasNumber && hasSymbol;
}


//____________________TO BE CHANGED_________________________
void _handleSubmit() {
  if (isLogin) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  } else {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}



}
