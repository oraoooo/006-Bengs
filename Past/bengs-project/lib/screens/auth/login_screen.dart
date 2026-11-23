import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_repository.dart';
import '../../theme/app_colors.dart';
import 'forgot_password_screen.dart';
import 'phone_signin_screen.dart';
import 'signup_screen.dart';
import 'widgets/auth_scaffold.dart';

/// bengs01.pdf screen 4. Successful sign-in doesn't navigate anywhere —
/// [AuthGate] is listening to the auth state stream and
/// swaps to MainScaffold on its own.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await AuthRepository.signIn(email: _email.text.trim(), password: _password.text);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Log in failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Log In',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              AuthTextField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  activeColor: AppColors.amber,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Remember me', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                ),
                child: const Text('Forgot password?', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Log In', onPressed: _submit, isLoading: _isLoading),
        const SizedBox(height: 28),
        const AuthOrDivider(),
        const SizedBox(height: 28),
        AuthNavyButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata,
          onPressed: () async {
            try {
              await AuthRepository.signInWithGoogle();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
            }
          },
        ),
        const SizedBox(height: 20),
        AuthNavyButton(
          label: 'Continue with phone',
          icon: Icons.phone_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PhoneSignInScreen()),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SignUpScreen()),
            ),
            child: const Text.rich(
              TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(color: Colors.white, fontSize: 14),
                children: [
                  TextSpan(text: 'Register', style: TextStyle(color: AppColors.amber)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
