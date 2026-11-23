import 'package:flutter/material.dart';
import '../models/leave_within_option.dart';
import '../screens/driver/driver_onboarding_gate.dart';
import '../screens/friends/friends_tab.dart';
import '../screens/home/home_tab.dart';
import '../screens/inbox/inbox_tab.dart';
import '../screens/profile/profile_tab.dart';
import '../screens/schedule/schedule_tab.dart';
import '../services/beng_repository.dart';
import '../services/notification_repository.dart';
import '../theme/app_colors.dart';

/// FRD §4.3 — the 5-tab bottom navigation. Position 3 (Home) is visually
/// elevated and distinct from the other four, per the design brief:
/// "5 buttons in the lower navbar, home in the middle with diff highlight."
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, required this.isDriverVerified});

  /// Sourced from the authenticated user's driver_verification.status by
  /// AuthGate, which owns the auth/session lookups this widget stays free of.
  final bool isDriverVerified;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

enum _Tab { schedule, friends, home, inbox, profile }

class _MainScaffoldState extends State<MainScaffold> {
  _Tab _current = _Tab.schedule;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final count = await NotificationRepository.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Badge count is a nice-to-have — leave it at 0 rather than crash.
    }
  }

  void _selectTab(_Tab tab) {
    setState(() => _current = tab);
    // Whatever was just read on the Inbox tab should clear the badge.
    if (tab != _Tab.inbox) _refreshUnreadCount();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _Tab.values.indexOf(_current),
          children: [
            // Existing calendar/list Home, unchanged content — just
            // relabeled "Schedule" per FRD §4.3.
            const ScheduleTab(),
            const FriendsTab(),
            HomeTab(
              isDriverVerified: widget.isDriverVerified,
              onSearchRides: (LeaveWithinOption leaveWithin) async {
                try {
                  final rides = await BengRepository.searchSpontaneousRides(leaveWithin);
                  if (!mounted) return;
                  _showSnack('Found ${rides.length} ride(s) leaving within ${leaveWithin.label}');
                } catch (e) {
                  if (!mounted) return;
                  _showSnack('Search failed: $e');
                }
              },
              onGoOnline: (seats, price, activeMinutes) async {
                try {
                  await BengRepository.goOnline(
                    seats: seats,
                    pricePerPassenger: price,
                    activeMinutes: activeMinutes,
                  );
                  if (!mounted) return;
                  _showSnack('You\'re online — $seats seat(s), Rp$price, active ${activeMinutes}min');
                } catch (e) {
                  if (!mounted) return;
                  _showSnack('Could not go online: $e');
                }
              },
              onRequireDriverVerification: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DriverOnboardingGate()),
                );
              },
            ),
            const InboxTab(),
            const ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _BengBottomNav(
        current: _current,
        unreadCount: _unreadCount,
        onSelect: _selectTab,
      ),
    );
  }
}

class _BengBottomNav extends StatelessWidget {
  const _BengBottomNav({required this.current, required this.unreadCount, required this.onSelect});

  final _Tab current;
  final int unreadCount;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.hairline, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _NavItem(
            icon: Icons.calendar_today_outlined,
            label: 'Schedule',
            isSelected: current == _Tab.schedule,
            onTap: () => onSelect(_Tab.schedule),
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Friends',
            isSelected: current == _Tab.friends,
            onTap: () => onSelect(_Tab.friends),
          ),
          _HomeNavItem(
            isSelected: current == _Tab.home,
            onTap: () => onSelect(_Tab.home),
          ),
          _NavItem(
            icon: Icons.mail_outline,
            label: 'Inbox',
            isSelected: current == _Tab.inbox,
            onTap: () => onSelect(_Tab.inbox),
            showDot: unreadCount > 0,
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            isSelected: current == _Tab.profile,
            onTap: () => onSelect(_Tab.profile),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryBlue : AppColors.mutedText;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: color),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: color)),
          ],
        ),
      ),
    );
  }
}

/// The elevated center "Home" tab — visually distinct per the design brief.
class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Transform.translate(
        offset: const Offset(0, -10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
              child: const Icon(Icons.location_on, size: 20, color: AppColors.navyText),
            ),
            const SizedBox(height: 3),
            const Text(
              'Home',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.navyText),
            ),
          ],
        ),
      ),
    );
  }
}
