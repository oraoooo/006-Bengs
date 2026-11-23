import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_repository.dart';
import '../../theme/app_colors.dart';
import 'widgets/auth_scaffold.dart';

/// bengs01.pdf screen 7 — unchanged, carried over as-is. Used for BR-08's
/// phone sign-in: [PhoneSignInScreen] sends the code, this verifies it.
/// A successful verify() call establishes a session, and `_AuthGate`'s
/// stream takes over from there — no navigation needed on success.
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _confirm() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the full 6-digit code')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthRepository.verifyPhoneOtp(phone: widget.phone, token: _code);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await AuthRepository.sendPhoneOtp(widget.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not resend: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify OTP',
      children: [
        const Text(
          'Enter your OTP which has been sent to your phone and completely verify your account.',
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 40,
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(color: AppColors.navyText, fontSize: 20, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(counterText: '', border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white))),
                onChanged: (value) {
                  if (value.isNotEmpty && i < 5) {
                    _focusNodes[i + 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: _resend,
            child: const Text('Resend code', style: TextStyle(color: Colors.white70)),
          ),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(label: 'Confirm', onPressed: _confirm, isLoading: _isLoading),
      ],
    );
  }
}
