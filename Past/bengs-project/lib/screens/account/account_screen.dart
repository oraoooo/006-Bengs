import 'package:flutter/material.dart';
import '../../services/auth_repository.dart';
import '../../services/notification_preferences.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../profile/cool_profile_screen.dart';
import '../profile/edit_profile_screen.dart';
import 'placeholder_content_screen.dart';

/// bengs01.pdf's Account screen — listed in CLAUDE.md as "unchanged,
/// carry over as-is" but never actually built; ProfileTab (ratings,
/// vehicle, driver verification) covers different ground than this one,
/// which is settings/account-management, not profile display.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<(bool, bool)> _notificationPrefsFuture;

  @override
  void initState() {
    super.initState();
    _notificationPrefsFuture = _loadPrefs();
  }

  Future<(bool, bool)> _loadPrefs() async {
    final push = await NotificationPreferences.getPushEnabled();
    final promotional = await NotificationPreferences.getPromotionalEnabled();
    return (push, promotional);
  }

  Future<void> _signOut() async {
    await AuthRepository.signOut();
    // _AuthGate's auth-state stream takes it from here.
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.profile['first_name'] as String? ?? '';
    final surname = widget.profile['surname'] as String? ?? '';
    final fullName = [firstName, surname].where((s) => s.isNotEmpty).join(' ');
    final email = SupabaseService.currentUser?.email;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('Account'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryBlue,
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: Text(fullName.isEmpty ? 'BENGS user' : fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.navyText))),
            if (email != null) Center(child: Text(email, style: const TextStyle(fontSize: 13, color: AppColors.mutedText))),
            const SizedBox(height: 20),
            _SectionGroup(title: 'My Account', children: [
              _AccountRow(
                icon: Icons.person_outline,
                label: 'Personal information',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProfileScreen(profile: widget.profile))),
              ),
              _AccountRow(
                icon: Icons.diversity_3_outlined,
                label: 'Cool People Profile',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoolProfileScreen(profile: widget.profile))),
              ),
              const _AccountRow(icon: Icons.language, label: 'Language', trailingText: 'English (US)'),
              _AccountRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PlaceholderContentScreen(
                    title: 'Privacy Policy',
                    message: "BENGS's privacy policy will appear here. This screen is a structural placeholder, real legal copy hasn't been written yet.",
                  ),
                )),
              ),
            ]),
            const SizedBox(height: 16),
            _SectionGroup(
              title: 'Notifications',
              children: [
                FutureBuilder<(bool, bool)>(
                  future: _notificationPrefsFuture,
                  builder: (context, snapshot) {
                    final (push, promotional) = snapshot.data ?? (true, false);
                    return Column(
                      children: [
                        _ToggleRow(
                          icon: Icons.notifications_none,
                          label: 'Push Notifications',
                          value: push,
                          onChanged: (v) async {
                            await NotificationPreferences.setPushEnabled(v);
                            setState(() => _notificationPrefsFuture = _loadPrefs());
                          },
                        ),
                        _ToggleRow(
                          icon: Icons.notifications_none,
                          label: 'Promotional Notifications',
                          value: promotional,
                          onChanged: (v) async {
                            await NotificationPreferences.setPromotionalEnabled(v);
                            setState(() => _notificationPrefsFuture = _loadPrefs());
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionGroup(title: 'More', children: [
              _AccountRow(
                icon: Icons.help_outline,
                label: 'Help Center',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PlaceholderContentScreen(
                    title: 'Help Center',
                    message: "Support content will appear here. In the meantime, reach out via WhatsApp from a beng you're on for ride-specific issues.",
                  ),
                )),
              ),
              _AccountRow(icon: Icons.logout, label: 'Log Out', labelColor: Colors.red, onTap: _signOut),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navyText)),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.label, this.trailingText, this.onTap, this.labelColor});

  final IconData icon;
  final String label;
  final String? trailingText;
  final VoidCallback? onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: labelColor ?? AppColors.navyText),
      title: Text(label, style: TextStyle(fontSize: 13, color: labelColor ?? AppColors.navyText)),
      trailing: trailingText != null
          ? Text(trailingText!, style: const TextStyle(fontSize: 12, color: AppColors.mutedText))
          : (onTap != null ? const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedText) : null),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.navyText),
      title: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.navyText)),
      trailing: Switch(value: value, onChanged: onChanged, activeTrackColor: const Color(0xFF34C759)),
    );
  }
}
