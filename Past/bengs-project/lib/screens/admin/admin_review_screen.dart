import 'package:flutter/material.dart';
import '../../services/admin_repository.dart';
import '../../theme/app_colors.dart';
import '../../utils/vehicle_display.dart';

/// Replaces hand-editing driver_verification.status / vehicle.is_verified
/// in Supabase's table editor — every prior KYC/vehicle test had to do
/// that manually since no in-app approval step existed. Only reachable by
/// an account with profiles.is_admin = true (see AdminRepository).
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  late Future<List<Map<String, dynamic>>> _verificationsFuture;
  late Future<List<Map<String, dynamic>>> _vehiclesFuture;
  final _busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    _verificationsFuture = AdminRepository.getPendingDriverVerifications();
    _vehiclesFuture = AdminRepository.getPendingVehicles();
  }

  void _refresh() {
    setState(() {
      _verificationsFuture = AdminRepository.getPendingDriverVerifications();
      _vehiclesFuture = AdminRepository.getPendingVehicles();
    });
  }

  Future<String?> _promptReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'Reason'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: controller.text.trim().isEmpty ? null : () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveVerification(String id) async {
    setState(() => _busyIds.add(id));
    try {
      await AdminRepository.approveDriverVerification(id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not approve: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _rejectVerification(String id) async {
    final reason = await _promptReason('Reject KYC');
    if (reason == null) return;
    setState(() => _busyIds.add(id));
    try {
      await AdminRepository.rejectDriverVerification(id, reason);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reject: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _approveVehicle(String id) async {
    setState(() => _busyIds.add(id));
    try {
      await AdminRepository.approveVehicle(id);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not approve: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Future<void> _rejectVehicle(String id) async {
    final reason = await _promptReason('Reject Vehicle');
    if (reason == null) return;
    setState(() => _busyIds.add(id));
    try {
      await AdminRepository.rejectVehicle(id, reason);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not reject: $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Review'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Driver Verifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _verificationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                final items = snapshot.data ?? [];
                if (items.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nothing pending', style: TextStyle(color: AppColors.mutedText)));
                return Column(
                  children: items.map((v) {
                    final id = v['id'] as String;
                    final profile = v['profile'] as Map<String, dynamic>?;
                    final name = [profile?['first_name'], profile?['surname']].where((s) => s != null && (s as String).isNotEmpty).join(' ');
                    return _ReviewCard(
                      title: name.isEmpty ? 'Unknown' : name,
                      subtitle: 'KTP: ${v['ktp_full_name']} (${v['id_number']})\n${v['address']}, ${v['village']}, ${v['district']}, ${v['city']}, ${v['province']} ${v['postcode']}',
                      photoPaths: [v['id_card_photo_url'] as String?, v['id_card_selfie_url'] as String?].whereType<String>().toList(),
                      isBusy: _busyIds.contains(id),
                      onApprove: () => _approveVerification(id),
                      onReject: () => _rejectVerification(id),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('Vehicles', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _vehiclesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                final items = snapshot.data ?? [];
                if (items.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nothing pending', style: TextStyle(color: AppColors.mutedText)));
                return Column(
                  children: items.map((v) {
                    final id = v['id'] as String;
                    final profile = v['profile'] as Map<String, dynamic>?;
                    final name = [profile?['first_name'], profile?['surname']].where((s) => s != null && (s as String).isNotEmpty).join(' ');
                    final type = v['vehicle_type'] == 'motor' ? 'Motor' : 'Mobil';
                    final brandModel = vehicleBrandModelLabel(v);
                    return _ReviewCard(
                      title: name.isEmpty ? 'Unknown' : name,
                      subtitle: '$type · ${brandModel ?? 'Unknown brand/model'} · ${v['vehicle_license_plate']}',
                      photoPaths: [v['vehicle_registration_cert_url'] as String?].whereType<String>().toList(),
                      isBusy: _busyIds.contains(id),
                      onApprove: () => _approveVehicle(id),
                      onReject: () => _rejectVehicle(id),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.subtitle,
    required this.photoPaths,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final String title;
  final String subtitle;
  final List<String> photoPaths;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
          if (photoPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photoPaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _SignedThumbnail(path: photoPaths[index]),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isBusy ? null : onApprove,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                  child: isBusy
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignedThumbnail extends StatelessWidget {
  const _SignedThumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AdminRepository.signedDocumentUrl(path),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(width: 90, height: 90, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox(width: 90, height: 90, child: Icon(Icons.broken_image_outlined, color: AppColors.mutedText));
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(snapshot.data!))),
            ),
            child: Image.network(snapshot.data!, width: 90, height: 90, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
