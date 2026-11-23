import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_repository.dart';
import 'verify_otp_screen.dart';
import 'widgets/auth_scaffold.dart';

/// BR-08 phone auth entry point: collects the number, sends the OTP, then
/// hands off to [VerifyOtpScreen]. Not one of the 23 original screens on
/// its own — the original design only shows the OTP step.
class PhoneSignInScreen extends StatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    final phone = _phone.text.trim();
    try {
      await AuthRepository.sendPhoneOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VerifyOtpScreen(phone: phone)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send code: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Log In with Phone',
      children: [
        Form(
          key: _formKey,
          child: AuthTextField(
            label: 'Phone Number',
            controller: _phone,
            hint: '+62...',
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().length < 8) ? 'Enter a valid phone number' : null,
          ),
        ),
        AuthPrimaryButton(label: 'Send Code', onPressed: _submit, isLoading: _isLoading),
      ],
    );
  }
}
