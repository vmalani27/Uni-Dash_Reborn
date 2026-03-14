import 'package:flutter/material.dart';
import '../../../theme.dart';
import 'auth_form.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kBgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: kBgElevated.withOpacity(0.8),
          width: 1.2,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: AuthForm(),
      ),
    );
  }
}
