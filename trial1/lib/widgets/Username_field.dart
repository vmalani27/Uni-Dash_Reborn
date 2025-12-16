import 'package:flutter/material.dart';

class UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool? isValid;

  const UsernameField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    Icon? suffixIcon;

    if (controller.text.isNotEmpty) {
      if (isValid == true) {
        suffixIcon = const Icon(Icons.check_circle, color: Colors.green, size: 20);
      } else if (isValid == false) {
        suffixIcon = const Icon(Icons.error, color: Colors.red, size: 20);
      }
    }

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF3A3A3A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
