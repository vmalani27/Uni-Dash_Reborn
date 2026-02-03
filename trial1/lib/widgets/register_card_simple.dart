import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/profile_setup_screen.dart';
import 'package:trial1/services/authentication_service.dart';
import 'Password_field.dart';
import 'Username_field.dart';

class RegisterCard extends StatefulWidget {
  const RegisterCard({super.key});

  @override
  State<RegisterCard> createState() => _RegisterCardState();
}

class _RegisterCardState extends State<RegisterCard>
    with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final RegExp _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');

  bool showPasswordField = false;
  bool showConfirmField = false;
  bool passwordValid = false;
  bool confirmValid = false;

  late AnimationController titleController;
  late Animation<double> titleFade;
  String lastTitle = "";

  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorTextMsg;

  @override
  void initState() {
    super.initState();

    titleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    titleFade = CurvedAnimation(
      parent: titleController,
      curve: Curves.easeInOut,
    );

    emailController.addListener(() {
      final email = emailController.text;
      final valid = validateEmail(email);
      setState(() {
        if (valid && !showPasswordField) {
          showPasswordField = true;
        } else if (!valid && showPasswordField) {
          showPasswordField = false;
          showConfirmField = false;
        }
      });
    });

    passwordController.addListener(() {
      final pass = passwordController.text;
      final valid = validatePassword(pass);

      setState(() {
        passwordValid = valid;
        if (valid && !showConfirmField) {
          showConfirmField = true;
        }
      });
    });

    confirmPasswordController.addListener(() {
      setState(() {
        confirmValid =
            confirmPasswordController.text == passwordController.text;
      });
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTitle = _currentTitle;

    // Animate only when the title changes
    if (currentTitle != lastTitle) {
      lastTitle = currentTitle;
      titleController.forward(from: 0);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // TITLE WITH FADE
            FadeTransition(
              opacity: titleFade,
              child: Text(
                currentTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
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
            if (emailController.text.isNotEmpty) const SizedBox(height: 16),

            // PASSWORD FIELD
            if (showPasswordField)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    PasswordField(
                      controller: passwordController,
                      hint: "Password",
                    ),
                    const SizedBox(height: 10),
                    if (!showConfirmField) _buildPasswordRules(),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // CONFIRM PASSWORD FIELD
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: showConfirmField
                  ? PasswordField(
                      key: const ValueKey("confirmField"),
                      controller: confirmPasswordController,
                      hint: "Confirm Password",
                    )
                  : const SizedBox.shrink(),
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

            // REGISTER BUTTON
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSubmit && !_isLoading ? _handleRegister : null,
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
                    : const Text("Register"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _currentTitle {
    if (emailController.text.isEmpty) return "Create an Account";
    if (!showPasswordField) return "Create an Account";
    if (!showConfirmField) return "Set a secure password";
    return "Confirm Password";
  }

  Widget _buildPasswordRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rule("At least 8 characters", passwordValid),
        _rule(
          "One uppercase letter",
          passwordController.text.contains(RegExp(r'[A-Z]')),
        ),
        _rule("One number", passwordController.text.contains(RegExp(r'[0-9]'))),
        _rule(
          "One symbol",
          passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]')),
        ),
      ],
    );
  }

  Widget _rule(String text, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: ok ? Colors.green : Colors.black54,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: ok ? Colors.green : Colors.black54,
          ),
        ),
      ],
    );
  }

  bool get _canSubmit {
    return showConfirmField && confirmValid;
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorTextMsg = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    try {
      if (!validateEmail(email)) {
        setState(() {
          _errorTextMsg = "Please enter a valid email.";
        });
        return;
      }
      if (password != confirmPasswordController.text) {
        setState(() {
          _errorTextMsg = "Passwords do not match.";
        });
        return;
      }
      final user = await _authService.registerWithEmail(email, password);
      if (user != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorTextMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool validatePassword(String pass) {
    return pass.length >= 8 &&
        pass.contains(RegExp(r'[A-Z]')) &&
        pass.contains(RegExp(r'[0-9]')) &&
        pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
  }

  bool validateEmail(String email) {
    return _emailRegExp.hasMatch(email.trim());
  }
}
