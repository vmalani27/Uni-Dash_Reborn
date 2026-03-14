import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../services/authentication_service.dart';

class AuthForm extends StatefulWidget {
  const AuthForm({super.key});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorText;
  bool _isRegister = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 500;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isRegister ? 'Create account' : 'Sign in',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: kTextPrimary,
                fontWeight: FontWeight.w700,
                fontSize: isSmall ? 20 : 22,
              ),
        ),
        if (!isSmall) ...[
          const SizedBox(height: 4),
          Text(
            _isRegister ? 'Join UniDash to get started' : 'Welcome back to UniDash',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kTextSecondary,
              fontSize: 13,
            ),
          )
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kTextPrimary),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: TextStyle(color: kTextSecondary),
            filled: true,
            fillColor: kBgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kTextPrimary),
          decoration: InputDecoration(
            labelText: 'Password',
            labelStyle: TextStyle(color: kTextSecondary),
            filled: true,
            fillColor: kBgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            isDense: true,
          ),
        ),
        if (_isRegister) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: kTextPrimary),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: TextStyle(color: kTextSecondary),
              filled: true,
              fillColor: kBgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              isDense: true,
            ),
          ),
        ],
        if (_errorText != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 0.5),
            ),
            child: Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentPrimary,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: _isLoading ? null : _isRegister ? _onRegister : _onSignIn,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : Text(_isRegister ? 'Create Account' : 'Sign In'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Text(
                _isRegister ? 'Already have an account? ' : 'No account yet? ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: kTextSecondary,
                  fontSize: 13,
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isRegister = !_isRegister;
                          _errorText = null;
                        });
                      },
                style: TextButton.styleFrom(
                  foregroundColor: kAccentPrimary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _isRegister ? 'Sign In' : 'Register',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Email and password are required');
      return;
    }

    if (!_validateEmail(email)) {
      setState(() => _errorText = 'Enter a valid email address');
      return;
    }

    if (!_validatePassword(password)) {
      setState(() => _errorText = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = await _authService.signInWithEmail(email, password);
      if (user != null && mounted) {
        // Success - AuthGate will handle navigation automatically
        _emailController.clear();
        _passwordController.clear();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = _getErrorMessage(e.toString());
        });
      }
    }
  }

  void _onRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorText = 'All fields are required');
      return;
    }

    if (!_validateEmail(email)) {
      setState(() => _errorText = 'Enter a valid email address');
      return;
    }

    if (!_validatePassword(password)) {
      setState(() => _errorText = 'Password must be at least 6 characters');
      return;
    }

    if (password != confirm) {
      setState(() => _errorText = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = await _authService.registerWithEmail(email, password);
      if (user != null && mounted) {
        // Success - AuthGate will handle navigation automatically
        _emailController.clear();
        _passwordController.clear();
        _confirmController.clear();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = _getErrorMessage(e.toString());
        });
      }
    }
  }

  String _getErrorMessage(String errorCode) {
    if (errorCode.contains('user-not-found')) {
      return 'Email not found. Please register first.';
    } else if (errorCode.contains('wrong-password')) {
      return 'Incorrect password. Try again.';
    } else if (errorCode.contains('user-disabled')) {
      return 'This account has been disabled.';
    } else if (errorCode.contains('email-already-in-use')) {
      return 'Email already registered. Try signing in.';
    } else if (errorCode.contains('invalid-email')) {
      return 'Invalid email address.';
    } else if (errorCode.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    } else if (errorCode.contains('operation-not-allowed')) {
      return 'This operation is not allowed.';
    } else if (errorCode.contains('too-many-requests')) {
      return 'Too many failed attempts. Try again later.';
    } else if (errorCode.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    }
    return errorCode;
  }
}
