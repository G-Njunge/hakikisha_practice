import 'package:flutter/material.dart';

/// The Hakikisha logo. It's drawn on a white background, so it sits on a
/// rounded white card to look intentional in dark mode too.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.12),
      child: ColoredBox(
        color: Colors.white,
        child: Image.asset(
          'assets/images/hakikisha-logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: 'Hakikisha — Defining future health',
        ),
      ),
    );
  }
}
