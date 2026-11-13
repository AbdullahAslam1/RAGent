import 'package:flutter/material.dart';

/// Fades a child in while sliding it up slightly. Plays once when first built.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double offsetY;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.offsetY = 14,
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * offsetY),
          child: child,
        ),
      ),
    );
  }
}