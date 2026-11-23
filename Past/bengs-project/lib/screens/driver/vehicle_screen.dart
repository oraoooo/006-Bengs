import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/driver_repository.dart';
import '../../theme/app_colors.dart';

/// CLAUDE.md required change: an explicit Motor/Mobil selector (BR-06),
/// not free-text "Car". Reached from the driver-onboarding flow, after KYC.
///
/// Brand/model per FRD §6 VEH-01 (updated 2026-09-08): picked from the
/// vehicle_brand/vehicle_model lookup tables, not free text. Vehicle type is
/// picked first; the brand dropdown is unfiltered (a brand can sell both
/// motor and mobil), but the model dropdown filters to vehicle_model rows
/// matching both the selected brand and vehicle type. Both dropdowns end
/// with an "Other, not listed" option that reveals a free-text field
/// instead — migration 20260908000200's check constraints reject having
/// both a lookup id and free text set at once, so this UI never lets that
/// state occur to begin with (see _otherSentinel handling below).
class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key, this.popToRootOnSave = false});

  /// KYC onboarding should return to the tab shell. Add-a-Beng only needs
  /// a single pop so the form stays open with the new vehicle selected.
  final bool popToRootOnSave;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

/// Sentinel value for the "Other, not listed" dropdown entry — brand/model
/// ids are UUID strings, so this can't collide with a real row.
const _otherSentinel = '__other__';

class _VehicleScreenState extends State<VehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _plate = TextEditingController();
  final _brandOther = TextEditingController();
  final _modelOther = TextEditingController();
  String _vehicleType = 'motor';
  bool _isLoading = false;
  Uint8List? _registrationCertPhoto;

  late Future<void> _lookupsFuture;
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _models = [];

  String? _selectedBrandId;
  bool _brandIsOther = false;
  String? _selectedModelId;
  bool _modelIsOther = false;

  @override
  void initState() {
    super.initState();
    _lookupsFuture = _loadLookups();
  }

  Future<void> _loadLookups() async {
    final results = await Future.wait([
      DriverRepository.getVehicleBrands(),
      DriverRepository.getVehicleModels(),
    ]);
    if (!mounted) return;
    setState(() {
      _brands = results[0];
      _models = results[1];
    });
  }

  @override
  void dispose() {
    _plate.dispose();
    _brandOther.dispose();
    _modelOther.dispose();
    super.dispose();
  }

  /// Models matching the selected brand + vehicle type. Empty whenever the
  /// brand itself is "Other" (no brand_id to filter by), which is exactly
  /// when the model field should fall back to free text too — there's no
  /// lookup row a free-text brand could ever match.
  List<Map<String, dynamic>> get _filteredModels {
    final brandId = _selectedBrandId;
    if (brandId == null) return const [];
    return _models.where((m) => m['brand_id'] == brandId && m['vehicle_type'] == _vehicleType).toList();
  }

  void _onVehicleTypeChanged(String type) {
    setState(() {
      _vehicleType = type;
      _resetModelSelection();
    });
  }

  void _onBrandChanged(String? value) {
    setState(() {
      if (value == _otherSentinel) {
        _brandIsOther = true;
        _selectedBrandId = null;
      } else {
        _brandIsOther = false;
        _selectedBrandId = value;
      }
      _resetModelSelection();
    });
  }

  void _resetModelSelection() {
    _selectedModelId = null;
    _modelIsOther = false;
    _modelOther.clear();
  }

  void _onModelChanged(String? value) {
    setState(() {
      if (value == _otherSentinel) {
        _modelIsOther = true;
        _selectedModelId = null;
      } else {
        _modelIsOther = false;
        _selectedModelId = value;
      }
    });
  }

  Future<void> _pickRegistrationCert() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _registrationCertPhoto = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open photo picker: $e')));
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_brandIsOther && _selectedBrandId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a brand, or choose "Other, not listed"')));
      return;
    }
    final modelAvailable = _filteredModels.isNotEmpty && !_brandIsOther;
    if (modelAvailable && !_modelIsOther && _selectedModelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a model, or choose "Other, not listed"')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final plate = _plate.text.trim();
      final certPhoto = _registrationCertPhoto;
      final certPath = certPhoto == null ? null : await DriverRepository.uploadVehicleDocument(plate, certPhoto);
      await DriverRepository.addVehicle(
        vehicleType: _vehicleType,
        brandId: _brandIsOther ? null : _selectedBrandId,
        brandOther: _brandIsOther ? _brandOther.text.trim() : null,
        // Brand-is-Other leaves no brand_id to filter models against, so the
        // model side must be free text too regardless of _modelIsOther.
        modelId: (_brandIsOther || _modelIsOther) ? null : _selectedModelId,
        modelOther: (_brandIsOther || _modelIsOther) ? _modelOther.text.trim() : null,
        licensePlate: plate,
        registrationCertPath: certPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          widget.popToRootOnSave
              ? "Vehicle added. Your KYC is pending review, you'll be able to go online as a driver once it's approved."
              : 'Vehicle added.',
        )),
      );
      if (widget.popToRootOnSave) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add vehicle: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Vehicle'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _lookupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Could not load vehicle brands: ${snapshot.error}'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vehicle Type', style: TextStyle(fontSize: 12, color: AppColors.mutedText)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _TypeButton(
                            label: 'Motor',
                            icon: Icons.two_wheeler,
                            isSelected: _vehicleType == 'motor',
                            onTap: () => _onVehicleTypeChanged('motor'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeButton(
                            label: 'Mobil',
                            icon: Icons.directions_car,
                            isSelected: _vehicleType == 'mobil',
                            onTap: () => _onVehicleTypeChanged('mobil'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _brandField(),
                    const SizedBox(height: 12),
                    _modelField(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _plate,
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'License plate is required' : null,
                      decoration: InputDecoration(
                        labelText: 'License Plate',
                        hintText: 'B 1234 ABC',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickRegistrationCert,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: _registrationCertPhoto == null ? Colors.grey.shade400 : AppColors.primaryBlue),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            if (_registrationCertPhoto != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.memory(_registrationCertPhoto!, width: 40, height: 40, fit: BoxFit.cover),
                              )
                            else
                              Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade600),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _registrationCertPhoto == null ? 'Photo of STNK (optional)' : 'STNK photo — tap to retake',
                                style: TextStyle(fontSize: 13, color: _registrationCertPhoto == null ? AppColors.mutedText : AppColors.navyText),
                              ),
                            ),
                          ],
                        ),
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
                            : const Text('Save Vehicle', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _brandField() {
    if (_brandIsOther) {
      return _otherTextField(
        label: 'Brand',
        controller: _brandOther,
        onUndo: () => setState(() {
          _brandIsOther = false;
          _brandOther.clear();
        }),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedBrandId,
      decoration: InputDecoration(
        labelText: 'Brand',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        for (final b in _brands) DropdownMenuItem(value: b['id'] as String, child: Text(b['name'] as String)),
        const DropdownMenuItem(value: _otherSentinel, child: Text('Other, not listed')),
      ],
      onChanged: _onBrandChanged,
      validator: (_) => (_selectedBrandId == null) ? 'Pick a brand' : null,
    );
  }

  Widget _modelField() {
    if (_brandIsOther || _modelIsOther) {
      return _otherTextField(
        label: 'Model',
        controller: _modelOther,
        // Once the brand itself is "Other" there's no lookup model list to
        // return to — only offer the undo affordance when a real brand was
        // picked and the user separately chose "Other" for the model.
        onUndo: _brandIsOther
            ? null
            : () => setState(() {
                  _modelIsOther = false;
                  _modelOther.clear();
                }),
      );
    }

    final models = _filteredModels;
    if (models.isEmpty) {
      // No lookup models for this brand+type combo — fall straight to free
      // text rather than showing a dropdown whose only option is "Other".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_modelIsOther) setState(() => _modelIsOther = true);
      });
      return _otherTextField(label: 'Model', controller: _modelOther, onUndo: null);
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedModelId,
      decoration: InputDecoration(
        labelText: 'Model',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        for (final m in models) DropdownMenuItem(value: m['id'] as String, child: Text(m['name'] as String)),
        const DropdownMenuItem(value: _otherSentinel, child: Text('Other, not listed')),
      ],
      onChanged: _onModelChanged,
      validator: (_) => (_selectedModelId == null) ? 'Pick a model' : null,
    );
  }

  Widget _otherTextField({required String label, required TextEditingController controller, required VoidCallback? onUndo}) {
    return TextFormField(
      controller: controller,
      validator: (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null,
      decoration: InputDecoration(
        labelText: '$label (not listed)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIcon: onUndo == null
            ? null
            : IconButton(
                tooltip: 'Choose from list instead',
                icon: const Icon(Icons.undo, size: 18),
                onPressed: onUndo,
              ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.white,
          border: Border.all(color: isSelected ? AppColors.primaryBlue : const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppColors.mutedText),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.navyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
