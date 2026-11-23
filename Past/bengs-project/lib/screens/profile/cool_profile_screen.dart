import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/profile_repository.dart';
import '../../theme/app_colors.dart';

/// Prep-only per bengs Draft.pdf's ADDITIONAL FEEDBACK section: "Profile
/// can also (optional) input details ... recommend people to fill this
/// first to help them find their 'cool people' when browsing". This
/// screen captures that data and its per-field visibility — it does not
/// implement the "cool person"/"cool friend" matching, tagging, or
/// filtering the doc describes; that needs its own design pass and a real
/// similarity/matching algorithm, not something to improvise here.
class CoolProfileScreen extends StatefulWidget {
  const CoolProfileScreen({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<CoolProfileScreen> createState() => _CoolProfileScreenState();
}

String? _formatRegion(Map<String, dynamic>? region) {
  if (region == null) return null;
  final parts = [region['village'], region['district'], region['city'], region['province']]
      .whereType<String>()
      .where((s) => s.isNotEmpty);
  return parts.isEmpty ? null : parts.join(', ');
}

class _CoolProfileScreenState extends State<CoolProfileScreen> {
  late final _bio = TextEditingController(text: widget.profile['bio'] as String?);
  late final _interests = TextEditingController(
    text: ((widget.profile['interests'] as List?)?.cast<String>() ?? const <String>[]).join(', '),
  );
  late final _jobTitle = TextEditingController(text: widget.profile['job_title'] as String?);
  late final _workplace = TextEditingController(text: widget.profile['workplace_name'] as String?);
  late final _instagram = TextEditingController(text: widget.profile['instagram_handle'] as String?);

  // Neighbourhood is a lookup (PROF-02, indonesia_region) rather than free
  // text — picked via search, not typed. _neighbourhoodLabel is display-only,
  // resolved from the joined row ProfileRepository.getMyProfile() returns;
  // _neighbourhoodId is the only thing actually saved.
  late String? _neighbourhoodId = widget.profile['neighbourhood_id'] as String?;
  late String? _neighbourhoodLabel = _formatRegion(widget.profile['neighbourhood'] as Map<String, dynamic>?);

  late final Map<String, String> _visibility = Map<String, String>.from(
    (widget.profile['profile_visibility'] as Map?)?.cast<String, dynamic>().map((k, v) => MapEntry(k, v as String)) ??
        const {
          'bio': 'public',
          'interests': 'public',
          'job_title': 'cool_friends',
          'workplace_name': 'cool_friends',
          'neighbourhood': 'cool_friends',
          'instagram_handle': 'cool_friends',
        },
  );
  late bool _allowCoolFriendsWhatsapp = widget.profile['allow_cool_friends_whatsapp'] as bool? ?? true;
  bool _isLoading = false;

  @override
  void dispose() {
    for (final c in [_bio, _interests, _jobTitle, _workplace, _instagram]) {
      c.dispose();
    }
    super.dispose();
  }

  /// "Since all of these toggles are essentially crucial, show a
  /// confirmation pop-up when they want to change it."
  Future<void> _confirmVisibilityChange(String field, String newValue) async {
    final label = newValue == 'public' ? 'Public' : 'Cool Friends only';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change visibility?'),
        content: Text('This field will become "$label". You can change it again anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) setState(() => _visibility[field] = newValue);
  }

  Future<void> _pickNeighbourhood() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _NeighbourhoodSearchSheet(),
    );
    if (picked == null) return;
    setState(() {
      _neighbourhoodId = picked['id'] as String;
      _neighbourhoodLabel = _formatRegion(picked);
    });
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      await ProfileRepository.updateCoolProfile(
        bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        interests: _interests.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        jobTitle: _jobTitle.text.trim().isEmpty ? null : _jobTitle.text.trim(),
        workplaceName: _workplace.text.trim().isEmpty ? null : _workplace.text.trim(),
        neighbourhoodId: _neighbourhoodId,
        instagramHandle: _instagram.text.trim().isEmpty ? null : _instagram.text.trim(),
        profileVisibility: _visibility,
        allowCoolFriendsWhatsapp: _allowCoolFriendsWhatsapp,
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
      appBar: AppBar(title: const Text('Cool People Profile'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              "Optional — fill this in to help others find their \"cool people\" when browsing friends or bengs. "
              "Not used for anything yet (matching by these fields is still being designed), but saved for when it is.",
              style: TextStyle(color: AppColors.mutedText, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            _field('Bio', _bio, 'bio', maxLines: 3),
            _field('Interests (comma-separated)', _interests, 'interests'),
            _field('Job title', _jobTitle, 'job_title'),
            _field('Workplace', _workplace, 'workplace_name'),
            _neighbourhoodField(),
            _field('Instagram', _instagram, 'instagram_handle'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Let cool friends message me on WhatsApp', style: TextStyle(fontSize: 13)),
              value: _allowCoolFriendsWhatsapp,
              onChanged: (v) => setState(() => _allowCoolFriendsWhatsapp = v),
            ),
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
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visibilityHeader(String label, String visibilityKey) {
    final isPublic = _visibility[visibilityKey] == 'public';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
        GestureDetector(
          onTap: () => _confirmVisibilityChange(visibilityKey, isPublic ? 'cool_friends' : 'public'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPublic ? AppColors.sheetLavender : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isPublic ? 'Public' : 'Cool Friends',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isPublic ? AppColors.primaryBlue : AppColors.mutedText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, String visibilityKey, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _visibilityHeader(label, visibilityKey),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// PROF-02: picked from indonesia_region via search, not typed — see
  /// _pickNeighbourhood. The dropdown/search will legitimately show no
  /// results until the ~83,000-row national import runs (FRD §13); that's
  /// expected, not a bug.
  Widget _neighbourhoodField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _visibilityHeader('Neighbourhood', 'neighbourhood'),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickNeighbourhood,
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: const Icon(Icons.search, size: 18),
              ),
              child: Text(
                _neighbourhoodLabel ?? 'Not set',
                style: TextStyle(color: _neighbourhoodLabel == null ? AppColors.mutedText : AppColors.navyText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search-as-you-type sheet against indonesia_region. A plain dropdown
/// doesn't fit here — the table is national in scope (~83,000 rows once
/// populated, FRD §13), so results are always a filtered, limited query,
/// never the full list.
class _NeighbourhoodSearchSheet extends StatefulWidget {
  const _NeighbourhoodSearchSheet();

  @override
  State<_NeighbourhoodSearchSheet> createState() => _NeighbourhoodSearchSheetState();
}

class _NeighbourhoodSearchSheetState extends State<_NeighbourhoodSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Future<List<Map<String, dynamic>>> _results = Future.value(const []);

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _results = ProfileRepository.searchNeighbourhoods(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Search neighbourhood', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Village, district, city, or province',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final results = snapshot.data ?? [];
                    if (_controller.text.trim().isEmpty) {
                      return const Center(child: Text('Start typing to search', style: TextStyle(color: AppColors.mutedText)));
                    }
                    if (results.isEmpty) {
                      return const Center(child: Text('No matches yet', style: TextStyle(color: AppColors.mutedText)));
                    }
                    return ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final region = results[index];
                        return ListTile(
                          title: Text(region['village'] as String? ?? ''),
                          subtitle: Text(_formatRegion(region)?.split(', ').skip(1).join(', ') ?? ''),
                          onTap: () => Navigator.of(context).pop(region),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
