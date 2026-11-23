import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/place.dart';
import '../../models/repeat_rule.dart';
import '../../services/beng_repository.dart';
import '../../services/profile_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/vehicle_display.dart';
import '../../widgets/location_search_field.dart';
import '../driver/vehicle_screen.dart';
import 'repeat/repeat_list_screen.dart';

/// Add-a-Beng — creates a scheduled beng, optionally recurring. Origin and
/// destination are real place search (GeocodingService/OpenRouteService)
/// now, not manually-typed coordinates — see LocationSearchField for the
/// fallback when ORS_API_KEY isn't configured. Reaching this screen at all
/// requires driver verification (see ScheduleTab's onTap for the gate).
class AddBengScreen extends StatefulWidget {
  const AddBengScreen({super.key});

  @override
  State<AddBengScreen> createState() => _AddBengScreenState();
}

class _AddBengScreenState extends State<AddBengScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _price = TextEditingController(text: '5000');
  Place? _origin;
  Place? _destination;
  int _maxPassenger = 2;
  DateTime? _departDateTime;
  RepeatRule _repeat = const RepeatRule();
  bool _isLoading = false;

  late Future<List<Map<String, dynamic>>> _vehiclesFuture;
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _vehiclesFuture = ProfileRepository.getMyVehicles().then((vehicles) {
      if (vehicles.isNotEmpty) {
        final defaultVehicle = vehicles.firstWhere((v) => v['is_default'] == true, orElse: () => vehicles.first);
        setState(() => _selectedVehicleId = defaultVehicle['id'] as String);
      }
      return vehicles;
    });
  }

  @override
  void dispose() {
    for (final c in [_label, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    setState(() => _departDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickRepeat() async {
    final startDate = _departDateTime ?? DateTime.now();
    final result = await Navigator.of(context).push<RepeatRule>(
      CupertinoPageRoute(builder: (_) => RepeatListScreen(initial: _repeat, startDate: startDate)),
    );
    if (result != null) setState(() => _repeat = result);
  }

  Future<void> _addVehicle() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const VehicleScreen()));
    if (!mounted || added != true) return;
    setState(() {
      _vehiclesFuture = ProfileRepository.getMyVehicles().then((vehicles) {
        if (vehicles.isNotEmpty) {
          final defaultVehicle = vehicles.firstWhere((v) => v['is_default'] == true, orElse: () => vehicles.first);
          _selectedVehicleId = defaultVehicle['id'] as String;
        }
        return vehicles;
      });
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_departDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a date and time')));
      return;
    }
    final vehicleId = _selectedVehicleId;
    if (vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a vehicle')));
      return;
    }
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick an origin and destination')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await BengRepository.createScheduledBeng(
        label: _label.text.trim().isEmpty ? null : _label.text.trim(),
        vehicleId: vehicleId,
        originName: origin.name,
        originLatitude: origin.latitude,
        originLongitude: origin.longitude,
        destinationName: destination.name,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
        price: int.parse(_price.text.trim()),
        maxPassenger: _maxPassenger,
        departDateTime: _departDateTime!,
        repeat: _repeat,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beng added. It now shows up in Find-a-Beng.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add beng: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = _departDateTime;
    final dtLabel = dt == null ? '' : '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a Beng'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navyText,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Label (optional)', _label, required: false),
                const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                _vehiclePicker(),
                const SizedBox(height: 8),
                const Text('Origin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                LocationSearchField(label: 'Origin', initialValue: _origin, onSelected: (place) => setState(() => _origin = place)),
                const SizedBox(height: 16),
                const Text('Destination', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                LocationSearchField(label: 'Destination', initialValue: _destination, onSelected: (place) => setState(() => _destination = place)),
                const SizedBox(height: 8),
                _field('Price per passenger (Rp)', _price, keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Seats available', style: TextStyle(fontSize: 13)),
                    Row(
                      children: [
                        IconButton(onPressed: _maxPassenger > 1 ? () => setState(() => _maxPassenger--) : null, icon: const Icon(Icons.remove_circle_outline)),
                        Text('$_maxPassenger'),
                        IconButton(onPressed: _maxPassenger < 6 ? () => setState(() => _maxPassenger++) : null, icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDateTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Depart date & time',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(dtLabel.isEmpty ? 'Tap to select' : dtLabel),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickRepeat,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Repeat',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      _repeat.frequency == RepeatFrequency.never ? "Doesn't repeat" : _repeat.summary(_departDateTime ?? DateTime.now()),
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
                        : const Text('Add Beng', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// BR-06 — an explicit Motor/Mobil selector over the driver's saved
  /// vehicles, not free text and not a silent default-vehicle lookup.
  Widget _vehiclePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
          }
          final vehicles = snapshot.data ?? [];
          if (vehicles.isEmpty) {
            return OutlinedButton.icon(
              onPressed: _addVehicle,
              icon: const Icon(Icons.add),
              label: const Text('Add a vehicle'),
            );
          }
          return RadioGroup<String>(
            groupValue: _selectedVehicleId,
            onChanged: (id) => setState(() => _selectedVehicleId = id),
            child: Column(
              children: [
                for (final v in vehicles)
                  RadioListTile<String>(
                    value: v['id'] as String,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppColors.primaryBlue,
                    secondary: Icon(
                      v['vehicle_type'] == 'motor' ? Icons.two_wheeler : Icons.directions_car,
                      color: AppColors.iconBlue,
                    ),
                    title: Text(
                      vehicleBrandModelLabel(v) ?? (v['vehicle_type'] == 'motor' ? 'Motor' : 'Mobil'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(v['vehicle_license_plate'] as String, style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: _addVehicle, icon: const Icon(Icons.add, size: 16), label: const Text('Add another vehicle')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool required = true, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
