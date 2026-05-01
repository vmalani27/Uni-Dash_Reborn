import 'package:flutter/material.dart';
import 'auth_form.dart';

class AuthCard extends StatelessWidget {
  final VoidCallback? onAuthSuccess;

  const AuthCard({super.key, this.onAuthSuccess});
@override
Widget build(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.9),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: AuthForm(onAuthSuccess: onAuthSuccess),
    ),
  );
}}