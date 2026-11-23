import 'package:flutter/material.dart';
import '../../services/auth_repository.dart';
import 'age_gate_screen.dart';
import 'widgets/auth_scaffold.dart';

/// Shown in place of MainScaffold when a signed-in user has no `profiles`
/// row yet — currently only reachable via Google OAuth, since
/// [AuthRepository.signInWithGoogle] authenticates but never collects
/// first name / surname / date of birth the way the email SignUpScreen
/// does in the same step. Without this, getMyProfile() 0-row PostgrestExceptions
/// everywhere a screen expects a profile to already exist.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.onComplete});

  /// Called after the profile row is created (and, if the account isn't
  /// under 18, only then) so `_AuthGate` re-checks and proceeds into the app.
  final VoidCallback onComplete;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  DateTime? _dateOfBirth;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
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

    setState(() => _isLoading = true);
    try {
      final result = await AuthRepository.completeOAuthProfile(
        firstName: _firstName.text.trim(),
        surname: _surname.text.trim(),
        dateOfBirth: _dateOfBirth!,
      );
      if (!mounted) return;
      if (result.needsParentalConsent) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgeGateScreen()));
        return;
      }
      widget.onComplete();
    } on UnderMinimumAgeException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be at least 13 years old to use BENGS')),
      );
      await AuthRepository.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save your profile: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Just one more step',
      showBack: false,
      children: [
        const Text(
          "We need a couple of details to finish setting up your account.",
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
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
                label: 'Date of Birth',
                controller: TextEditingController(text: _dobLabel),
                readOnly: true,
                hint: 'Select your date of birth',
                onTap: _pickDateOfBirth,
                validator: (_) => _dateOfBirth == null ? 'Date of birth is required' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        AuthPrimaryButton(label: 'Continue', onPressed: _submit, isLoading: _isLoading),
      ],
    );
  }
}
