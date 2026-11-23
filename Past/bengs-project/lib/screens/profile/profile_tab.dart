import 'package:flutter/material.dart';
import '../../services/auth_repository.dart';
import '../../services/driver_repository.dart';
import '../../services/profile_repository.dart';
import '../../theme/app_colors.dart';
import '../account/account_screen.dart';
import '../admin/admin_review_screen.dart';
import '../driver/vehicle_screen.dart';
import '../requests/reviewing_screen.dart';
import 'edit_profile_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<_ProfileData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final results = await Future.wait([
      ProfileRepository.getMyProfile(),
      ProfileRepository.getMyVehicles(),
      DriverRepository.getVerificationStatus(),
    ]);
    return _ProfileData(
      profile: results[0] as Map<String, dynamic>,
      vehicles: results[1] as List<Map<String, dynamic>>,
      driverStatus: results[2] as String?,
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _signOut() async {
    await AuthRepository.signOut();
    // _AuthGate's auth-state stream takes it from here — no navigation needed.
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load profile: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          final profile = data.profile;
          final firstName = profile['first_name'] as String? ?? '';
          final surname = profile['surname'] as String? ?? '';
          final fullName = [firstName, surname].where((s) => s.isNotEmpty).join(' ');
          final isAdmin = profile['is_admin'] == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: AppColors.navyText),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountScreen(profile: profile))),
                ),
              ),
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryBlue,
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.navyText))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _RatingCard(label: 'As Driver', rating: (profile['driver_rating'] as num?)?.toDouble(), count: profile['driver_count'] as int? ?? 0)),
                  const SizedBox(width: 12),
                  Expanded(child: _RatingCard(label: 'As Passenger', rating: (profile['passenger_rating'] as num?)?.toDouble(), count: profile['passenger_count'] as int? ?? 0)),
                ],
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Driver Verification',
                trailing: _StatusBadge(status: data.driverStatus),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Requests to review',
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReviewingScreen())),
                  child: const Text('Open'),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: data.vehicles.isEmpty ? 'No vehicle on file' : '${data.vehicles.length} vehicle(s)',
                trailing: TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehicleScreen()));
                    _refresh();
                  },
                  child: const Text('Add'),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Admin Review',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminReviewScreen())),
                    child: const Text('Open'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
                  );
                  if (saved == true) _refresh();
                },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), minimumSize: const Size.fromHeight(48)),
                child: const Text('Edit Profile'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Sign Out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({required this.profile, required this.vehicles, required this.driverStatus});

  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> vehicles;
  final String? driverStatus;
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.label, required this.rating, required this.count});

  final String label;
  final double? rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sheetLavender,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, size: 16, color: AppColors.amber),
              const SizedBox(width: 4),
              Text(rating?.toStringAsFixed(1) ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text('$label · $count', style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEEEEEE)), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: AppColors.navyText)),
          trailing,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'verified' => 'Verified',
      'pending' => 'Pending',
      'rejected' => 'Rejected',
      _ => 'Not started',
    };
    final color = switch (status) {
      'verified' => Colors.green,
      'pending' => AppColors.amber,
      'rejected' => Colors.red,
      _ => AppColors.mutedText,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
