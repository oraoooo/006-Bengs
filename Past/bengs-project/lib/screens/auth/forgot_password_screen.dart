import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_repository.dart';
import 'widgets/auth_scaffold.dart';

/// bengs01.pdf screen 6 — unchanged, carried over as-is.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await AuthRepository.sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() => _sent = true);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send reset email: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Forgot Password',
      children: [
        const Text(
          "Enter the email associated with your account and we'll send an "
          "email with a code to reset your password",
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_sent)
          const Text(
            'Check your inbox for the reset link.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          )
        else ...[
          Form(
            key: _formKey,
            child: AuthTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
          ),
          AuthPrimaryButton(label: 'Forgot Password', onPressed: _submit, isLoading: _isLoading),
        ],
      ],
    );
  }
}
