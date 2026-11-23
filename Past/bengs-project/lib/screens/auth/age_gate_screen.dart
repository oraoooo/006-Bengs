import 'package:flutter/material.dart';
import '../../services/auth_repository.dart';
import 'widgets/auth_scaffold.dart';

/// Net-new screen per CLAUDE.md's required changes: triggered inline during
/// signup when DOB indicates the account holder is 13-17 (BR-02/05). Not in
/// the original 23-screen design.
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _parentName = TextEditingController();
  final _parentPhone = TextEditingController();
  final _parentEmail = TextEditingController();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _parentName.dispose();
    _parentPhone.dispose();
    _parentEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await AuthRepository.submitParentalConsent(
        parentName: _parentName.text.trim(),
        parentPhoneNumber: _parentPhone.text.trim(),
        parentEmail: _parentEmail.text.trim().isEmpty ? null : _parentEmail.text.trim(),
        consentMethod: 'otp_sms',
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const AuthScaffold(
        title: 'Parental Consent',
        showBack: false,
        children: [
          Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 48),
          SizedBox(height: 16),
          Text(
            "Thanks! We've sent your parent/guardian a request to approve your account. "
            "You can log in once they confirm.",
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Parental Consent',
      showBack: false,
      children: [
        const Text(
          "Since you're under 18, BENGS needs a parent or guardian's contact "
          "details to confirm they're okay with you using the app (BR-02).",
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                label: "Parent/Guardian's Name",
                controller: _parentName,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              AuthTextField(
                label: "Parent/Guardian's Phone Number",
                controller: _parentPhone,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              AuthTextField(
                label: "Parent/Guardian's Email (optional)",
                controller: _parentEmail,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        AuthPrimaryButton(label: 'Send for Approval', onPressed: _submit, isLoading: _isLoading),
      ],
    );
  }
}
