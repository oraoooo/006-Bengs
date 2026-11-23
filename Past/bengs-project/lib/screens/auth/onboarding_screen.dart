import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../../widgets/bengs_wordmark.dart';
import 'auth_gate.dart';
import 'widgets/auth_scaffold.dart';

/// Figma Onboarding (`79:6633`). First launch only; "Get Started" marks
/// onboarding seen and continues to [AuthGate] (Log In / Sign Up).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const seenKey = 'onboarding_seen';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(seenKey) ?? false;
  }

  Future<void> _getStarted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const BengsWordmark(markSize: 66, fontSize: 46),
              const Spacer(),
              const Text(
                'Explore now\nto experience the benefits',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.amber,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share rides with people you already have some connection with — scheduled or on the spot.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 48),
              AuthPrimaryButton(label: 'Get Started', onPressed: () => _getStarted(context)),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
