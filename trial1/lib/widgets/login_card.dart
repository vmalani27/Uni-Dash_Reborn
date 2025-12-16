import 'dart:async';

import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/profile_setup_screen.dart';
import 'package:trial1/services/authentication_service.dart';
import 'Password_field.dart';
import 'Username_field.dart'; // We'll reuse this as EmailField for now

class LoginRegisterCard extends StatefulWidget {
  const LoginRegisterCard({super.key});

  @override
  State<LoginRegisterCard> createState() => _LoginRegisterCardState();
}

class _LoginRegisterCardState extends State<LoginRegisterCard>
    with TickerProviderStateMixin {
  bool isLogin = true;

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

  String lastTitle = ""; // 1. Track last shown title

  Timer? _usernameDebounce;

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
        if (!isLogin) {
          if (valid && !showPasswordField) {
            showPasswordField = true;
          } else if (!valid && showPasswordField) {
            showPasswordField = false;
            showConfirmField = false;
          }
        }
      });
    });

    passwordController.addListener(() {
      final pass = passwordController.text;
      final valid = validatePassword(pass);

      setState(() {
        passwordValid = valid;
        if (valid && !showConfirmField && !isLogin) {
          showConfirmField = true;
        }
      });
    });

    confirmPasswordController.addListener(() {
      setState(() {
        confirmValid = confirmPasswordController.text == passwordController.text;
      });
    });
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTitle = _currentTitle; // 2. Get current title

    // 3. Animate only when the title changes
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

            // ---------- TITLE WITH FADE ----------
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

            const SizedBox(height: 16),

            // ---------- TABS ----------
            Row(
              children: [
                _buildTab("Login", isActive: isLogin, onTap: () {
                  _resetRegisterFlow();
                  setState(() => isLogin = true);
                }),
                const SizedBox(width: 12),
                _buildTab("Register", isActive: !isLogin, onTap: () {
                  _resetRegisterFlow();
                  setState(() => isLogin = false);
                }),
              ],
            ),

            const SizedBox(height: 20),

            // ---------- USERNAME ----------
          
              Column(
                children: [
                  UsernameField(
                    controller: emailController,
                    hint: "Email",
                    isValid: emailController.text.isEmpty
                        ? null
                        : validateEmail(emailController.text),
                    onChanged: (value) {
                      setState(() {});
                    },
                    // Add keyboardType for email
                    // If you want, you can rename UsernameField to EmailField for clarity
                  ),
                  // Email validation UI removed as requested
                  // Only show spacing if password field is visible
                  if (isLogin || emailController.text.isNotEmpty)
                    const SizedBox(height: 16),
                ],
              ),

            // ---------- PASSWORD ----------
            if (isLogin || showPasswordField)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    PasswordField(
                      controller: passwordController,
                      hint: "Password",
                    ),
                    const SizedBox(height: 10),

                    // RULES
                    if (!isLogin && !showConfirmField)
                      _buildPasswordRules(),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ---------- CONFIRM PASSWORD ----------
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: (!isLogin && showConfirmField)
                  ? PasswordField(
                      key: const ValueKey("confirmField"),
                      controller: confirmPasswordController,
                      hint: "Confirm Password",
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 22),

            // ---------- SUBMIT BUTTON ----------
            if (_errorTextMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _errorTextMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSubmit && !_isLoading ? _handleAuth : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _canSubmit && !_isLoading ? const Color(0xFFE59A23) : Colors.grey,
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
                    : Text(isLogin ? "Login" : "Register"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- TITLE LOGIC ----------
  String get _currentTitle {
    if (isLogin) return "Welcome Back!";
    if (emailController.text.isEmpty) return "Create an Account";
    if (!showPasswordField) return "Create an Account";
    if (!showConfirmField) return "Set a secure password";
    return "Confirm Password";
  }

  // ---------- RULES ----------
  Widget _buildPasswordRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _rule("At least 8 characters", passwordValid),
        _rule("One uppercase letter", passwordController.text.contains(RegExp(r'[A-Z]'))),
        _rule("One number", passwordController.text.contains(RegExp(r'[0-9]'))),
        _rule("One symbol", passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))),
      ],
    );
  }

  Widget _rule(String text, bool ok) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.circle_outlined,
            size: 16, color: ok ? Colors.green : Colors.black54),
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

  // ---------- SUBMIT ENABLE LOGIC ----------
  bool get _canSubmit {
    if (isLogin) {
      return emailController.text.isNotEmpty &&
          passwordController.text.isNotEmpty;
    }
    return showConfirmField && confirmValid;
  }

  // ---------- SUBMIT HANDLER ----------
  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorTextMsg = null;
    });
    final email = emailController.text.trim();
    final password = passwordController.text;
    try {
      if (isLogin) {
        final user = await _authService.signInWithEmail(email, password);
        if (user != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorTextMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Reset when switching tabs
  void _resetRegisterFlow() {
    showPasswordField = false;
    showConfirmField = false;
    passwordValid = false;
    confirmPasswordController.clear();
    passwordController.clear();
    emailController.clear();
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

  Widget _buildTab(String label, {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.black : Colors.black54,
            ),
          ),
          if (isActive)
            Container(
              height: 2,
              width: 40,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE59A23),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _validText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.green, fontSize: 12),
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }
}
