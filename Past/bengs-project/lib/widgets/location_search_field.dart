import 'dart:async';
import 'package:flutter/material.dart';
import '../models/place.dart';
import '../services/geocoding_service.dart';
import '../theme/app_colors.dart';

/// Place-search-as-you-type, backed by GeocodingService (OpenRouteService).
/// Replaces the old "type a name, then type its latitude and longitude by
/// hand" pattern everywhere a beng's origin/destination gets set.
///
/// Degrades honestly rather than silently: if ORS_API_KEY isn't configured
/// yet, this shows a manual-coordinates fallback instead of a search box
/// that can never return anything, so the app stays usable before the key
/// is added.
class LocationSearchField extends StatefulWidget {
  const LocationSearchField({
    super.key,
    required this.label,
    required this.onSelected,
    this.initialValue,
  });

  final String label;
  final ValueChanged<Place> onSelected;
  final Place? initialValue;

  @override
  State<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends State<LocationSearchField> {
  late final _controller = TextEditingController(text: widget.initialValue?.name ?? '');
  final _manualLat = TextEditingController();
  final _manualLng = TextEditingController();
  Timer? _debounce;
  List<Place> _suggestions = [];
  bool _isSearching = false;
  bool _showManualEntry = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _manualLat.dispose();
    _manualLng.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearching = true;
        _error = null;
      });
      try {
        final results = await GeocodingService.autocomplete(value);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _isSearching = false;
          _error = 'Could not search places: $e';
        });
      }
    });
  }

  void _select(Place place) {
    _controller.text = place.name;
    setState(() => _suggestions = []);
    FocusScope.of(context).unfocus();
    widget.onSelected(place);
  }

  void _submitManual() {
    final lat = double.tryParse(_manualLat.text.trim());
    final lng = double.tryParse(_manualLng.text.trim());
    if (lat == null || lng == null || _controller.text.trim().isEmpty) return;
    widget.onSelected(Place(name: _controller.text.trim(), latitude: lat, longitude: lng));
  }

  @override
  Widget build(BuildContext context) {
    final configured = GeocodingService.isConfigured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          onChanged: configured ? _onChanged : null,
          readOnly: !configured,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: configured ? 'Search for a place' : null,
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: const TextStyle(fontSize: 11, color: Colors.red)),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E2E2)), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: _suggestions
                  .map((p) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.place_outlined, size: 18, color: AppColors.mutedText),
                        title: Text(p.name, style: const TextStyle(fontSize: 12.5)),
                        onTap: () => _select(p),
                      ))
                  .toList(),
            ),
          ),
        if (!configured) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: () => setState(() => _showManualEntry = !_showManualEntry),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Place search not configured yet. Enter coordinates manually', style: TextStyle(fontSize: 11)),
            ),
          ),
          if (_showManualEntry)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _manualLat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(labelText: 'Latitude', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    onChanged: (_) => _submitManual(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _manualLng,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(labelText: 'Longitude', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    onChanged: (_) => _submitManual(),
                  ),
                ),
              ]),
            ),
        ],
      ],
    );
  }
}
