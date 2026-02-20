import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import 'package:trial1/services/authentication_service.dart';
import 'Password_field.dart';
import 'Username_field.dart';

class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final RegExp _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');

  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorTextMsg;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Welcome Back!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),

          // EMAIL FIELD
          UsernameField(
            controller: emailController,
            hint: "Email",
            isValid: emailController.text.isEmpty
                ? null
                : validateEmail(emailController.text),
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 16),

          // PASSWORD FIELD
          PasswordField(
            controller: passwordController,
            hint: "Password",
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 22),

          // ERROR MESSAGE
          if (_errorTextMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _errorTextMsg!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),

          // LOGIN BUTTON
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _canSubmit && !_isLoading ? _handleLogin : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canSubmit && !_isLoading
                    ? const Color(0xFFE59A23)
                    : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 3,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text("Login"),
            ),
          ),
        ],
      ),
    );
  }

  bool get _canSubmit {
    return emailController.text.isNotEmpty &&
        passwordController.text.isNotEmpty;
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorTextMsg = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    try {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null && mounted) {
        Navigator.of(context).pop();
        // AuthGate will react automatically to Firebase auth change.
      }
    } catch (e) {
      setState(() {
        _errorTextMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool validateEmail(String email) {
    return _emailRegExp.hasMatch(email.trim());
  }
}
