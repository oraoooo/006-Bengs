import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_repository.dart';
import '../../theme/app_colors.dart';
import 'age_gate_screen.dart';
import 'login_screen.dart';
import 'widgets/auth_scaffold.dart';

/// bengs01.pdf screen 5, plus the required change from CLAUDE.md: a
/// top-level date-of-birth field, independent of any later KTP scan
/// (BR-02/03 — passengers never do KYC, so age-gating can't rely on it).
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  DateTime? _dateOfBirth;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String get _dobLabel {
    final dob = _dateOfBirth;
    if (dob == null) return '';
    return '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}';
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date of birth is required')));
      return;
    }
    if (_password.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await AuthRepository.signUp(
        email: _email.text.trim(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        surname: _surname.text.trim(),
        dateOfBirth: _dateOfBirth!,
      );
      if (!mounted) return;

      if (result.needsParentalConsent) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AgeGateScreen()),
        );
        return;
      }
      if (!result.hasSession) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your email to confirm your account, then log in')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      // else: session is live, _AuthGate's stream takes over automatically.
    } on UnderMinimumAgeException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be at least 13 years old to use BENGS')),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign Up',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                label: 'First Name',
                controller: _firstName,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your first name' : null,
              ),
              AuthTextField(
                label: 'Surname',
                controller: _surname,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your surname' : null,
              ),
              AuthTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
              AuthTextField(
                label: 'Date of Birth',
                controller: TextEditingController(text: _dobLabel),
                readOnly: true,
                hint: 'Select your date of birth',
                onTap: _pickDateOfBirth,
                validator: (_) => _dateOfBirth == null ? 'Date of birth is required' : null,
              ),
              AuthTextField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
              ),
              AuthTextField(
                label: 'Confirm Password',
                controller: _confirmPassword,
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Confirm your password' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        AuthPrimaryButton(label: 'Sign Up', onPressed: _submit, isLoading: _isLoading),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Text.rich(
              TextSpan(
                text: 'Already have an account? ',
                style: TextStyle(color: Colors.white70),
                children: [TextSpan(text: 'Log In', style: TextStyle(color: AppColors.amber))],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
