import 'package:flutter/material.dart';

/// The logo mark + "BENGS" text stacked, as it appears on every auth screen
/// in bengs01.pdf (splash, onboarding, login, sign up, ...). The PNG is a
/// crop of the actual design asset (see assets/images/bengs_logo_mark.png),
/// not a redrawn approximation — there's no vector source file to work from.
class BengsWordmark extends StatelessWidget {
  const BengsWordmark({super.key, this.markSize = 56, this.fontSize = 32});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/bengs_logo_mark.png', width: markSize, height: markSize),
        const SizedBox(height: 8),
        Text(
          'BENGS',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
