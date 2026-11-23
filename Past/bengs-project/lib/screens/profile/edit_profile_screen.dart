import 'package:flutter/material.dart';
import '../../services/profile_repository.dart';
import '../../theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.profile['first_name'] as String?);
  late final _surname = TextEditingController(text: widget.profile['surname'] as String?);
  late final _phoneNumber = TextEditingController(text: widget.profile['phone_number'] as String?);
  String? _gender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _gender = widget.profile['gender'] as String?;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _phoneNumber.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      await ProfileRepository.updateProfile(
        firstName: _firstName.text.trim(),
        surname: _surname.text.trim().isEmpty ? null : _surname.text.trim(),
        gender: _gender,
        phoneNumber: _phoneNumber.text.trim().isEmpty ? null : _phoneNumber.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _firstName,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _surname,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: InputDecoration(
                    labelText: 'Surname',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneNumber,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (for WhatsApp)',
                    hintText: '08123456789',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: _gender ?? '',
                  onChanged: (v) => setState(() => _gender = v),
                  child: const Row(
                    children: [
                      Expanded(child: RadioListTile<String>(contentPadding: EdgeInsets.zero, title: Text('Male'), value: 'M')),
                      Expanded(child: RadioListTile<String>(contentPadding: EdgeInsets.zero, title: Text('Female'), value: 'F')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
