import 'package:flutter/material.dart';
import '../../../theme.dart';

class AnimatedMailToInsight extends StatefulWidget {
  const AnimatedMailToInsight({super.key});

  @override
  State<AnimatedMailToInsight> createState() => _AnimatedMailToInsightState();
}

class _AnimatedMailToInsightState extends State<AnimatedMailToInsight> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final dx = 60.0 * t;
          return Row(
            children: [
              Icon(Icons.email_outlined, color: kTextSecondary, size: 22),
              Transform.translate(
                offset: Offset(dx, 0),
                child: Opacity(
                  opacity: 1 - t * 0.5,
                  child: Icon(Icons.arrow_forward_rounded, color: kTextSecondary, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Transform.translate(
                offset: Offset(dx * 1.2, 0),
                child: Opacity(
                  opacity: 0.5 + t * 0.5,
                  child: Icon(Icons.insights_outlined, color: kAccentPrimary, size: 22),
                ),
              ),
              const SizedBox(width: 8),
              Text('Smart Inbox', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: kTextSecondary)),
            ],
          );
        },
      ),
    );
  }
}
