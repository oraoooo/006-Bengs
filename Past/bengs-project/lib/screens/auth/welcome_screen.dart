import 'package:flutter/material.dart';
import '../../services/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/bengs_wordmark.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';
import 'phone_signin_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Figma Log In/Sign Up (`79:6647`). BR-08: Google + phone, no Facebook.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _continueWithGoogle(BuildContext context) async {
    try {
      await AuthRepository.signInWithGoogle();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
    }
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
              AuthPrimaryButton(
                label: 'Log In',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
              const SizedBox(height: 20),
              AuthNavyButton(
                label: 'Sign Up',
                foreground: AppColors.amber,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                ),
              ),
              const SizedBox(height: 40),
              const AuthOrDivider(),
              const SizedBox(height: 40),
              AuthNavyButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                onPressed: () => _continueWithGoogle(context),
              ),
              const SizedBox(height: 20),
              AuthNavyButton(
                label: 'Continue with phone',
                icon: Icons.phone_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhoneSignInScreen()),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                ),
                child: const Text('Forgot password?', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
