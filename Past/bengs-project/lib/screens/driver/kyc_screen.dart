import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/driver_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/age.dart';
import 'vehicle_screen.dart';

/// image_picker has no camera implementation on desktop (image_picker_macos/
/// _linux/_windows only ever open a file/gallery dialog) — forcing
/// ImageSource.camera there throws and the tap does nothing visible, which
/// is exactly the "cannot submit any photo" bug this was.
bool get _supportsCameraCapture => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

/// BR-03/04 — the KYC/KTP screen, re-scoped per CLAUDE.md to only be
/// reachable when a user opts into Driver mode (here: tapping "Go online"
/// while unverified), never a universal onboarding step every user sees.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumber = TextEditingController();
  final _fullName = TextEditingController();
  final _address = TextEditingController();
  final _province = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _village = TextEditingController();
  final _postcode = TextEditingController();
  DateTime? _dateOfBirth;
  String _gender = 'M';
  bool _isLoading = false;
  Uint8List? _ktpPhoto;
  Uint8List? _selfiePhoto;

  @override
  void dispose() {
    for (final c in [
      _idNumber,
      _fullName,
      _address,
      _province,
      _city,
      _district,
      _village,
      _postcode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isSelfie}) async {
    final source = _supportsCameraCapture ? await _chooseSource() : ImageSource.gallery;
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        preferredCameraDevice: isSelfie ? CameraDevice.front : CameraDevice.rear,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => isSelfie ? _selfiePhoto = bytes : _ktpPhoto = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open photo picker: $e')));
    }
  }

  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take a photo'), onTap: () => Navigator.of(context).pop(ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from library'), onTap: () => Navigator.of(context).pop(ImageSource.gallery)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date of birth (as on KTP) is required')));
      return;
    }
    if (calculateAge(_dateOfBirth!, DateTime.now()) < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drivers must be at least 18 years old (BR-01)')),
      );
      return;
    }
    if (_ktpPhoto == null || _selfiePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A photo of your KTP and a selfie are both required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ktpPath = await DriverRepository.uploadKtpPhoto(_ktpPhoto!);
      final selfiePath = await DriverRepository.uploadSelfiePhoto(_selfiePhoto!);
      await DriverRepository.submitKyc(
        idNumber: _idNumber.text.trim(),
        ktpFullName: _fullName.text.trim(),
        ktpDateOfBirth: _dateOfBirth!,
        ktpGender: _gender,
        address: _address.text.trim(),
        province: _province.text.trim(),
        city: _city.text.trim(),
        district: _district.text.trim(),
        village: _village.text.trim(),
        postcode: _postcode.text.trim(),
        idCardPhotoPath: ktpPath,
        idCardSelfiePath: selfiePath,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VehicleScreen(popToRootOnSave: true)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit KYC: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Verification'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "We need to confirm your identity before you can drive on BENGS. "
                  "This matches the ID you scan below.",
                  style: TextStyle(color: AppColors.mutedText, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                _Field(label: 'KTP Number', controller: _idNumber, keyboardType: TextInputType.number),
                _Field(label: 'Full Name (as on KTP)', controller: _fullName),
                _DateField(label: 'Date of Birth (as on KTP)', value: _dateOfBirth, onTap: _pickDateOfBirth),
                const SizedBox(height: 4),
                const Text('Gender', style: TextStyle(fontSize: 12, color: AppColors.mutedText)),
                RadioGroup<String>(
                  groupValue: _gender,
                  onChanged: (v) => setState(() => _gender = v!),
                  child: const Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Male', style: TextStyle(fontSize: 13)),
                          value: 'M',
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Female', style: TextStyle(fontSize: 13)),
                          value: 'F',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _PhotoRow(label: 'Photo of your KTP', bytes: _ktpPhoto, onTap: () => _pickPhoto(isSelfie: false)),
                _PhotoRow(label: 'Selfie holding your KTP', bytes: _selfiePhoto, onTap: () => _pickPhoto(isSelfie: true)),
                const SizedBox(height: 4),
                _Field(label: 'Address', controller: _address),
                _Field(label: 'Province', controller: _province),
                _Field(label: 'City', controller: _city),
                _Field(label: 'District', controller: _district),
                _Field(label: 'Village', controller: _village),
                _Field(label: 'Postcode', controller: _postcode, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
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
                        : const Text('Submit for Review', style: TextStyle(fontWeight: FontWeight.w700)),
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

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.label, required this.bytes, required this.onTap});

  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: bytes == null ? Colors.grey.shade400 : AppColors.primaryBlue),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (bytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(bytes!, width: 44, height: 44, fit: BoxFit.cover),
                )
              else
                Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bytes == null ? label : '$label — tap to retake',
                  style: TextStyle(fontSize: 13, color: bytes == null ? AppColors.mutedText : AppColors.navyText),
                ),
              ),
              if (bytes != null) const Icon(Icons.check_circle, color: Colors.green, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, this.keyboardType});

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? ''
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        readOnly: true,
        onTap: onTap,
        controller: TextEditingController(text: text),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
