import 'package:flutter/material.dart';
import '../../models/leave_within_option.dart';
import '../../theme/app_colors.dart';
import '../../widgets/beng_map_placeholder.dart';
import 'add_quick_beng_screen.dart';
import 'find_quick_beng_screen.dart';

/// "Quick Beng!" — bengs Draft.pdf's ADDITIONAL FEEDBACK section renames
/// this tab from a plain Find/Offer toggle to a disclaimer + two full-page
/// entry points ("add a quick beng" blue, "find a quick beng" yellow),
/// each its own screen rather than a mode swapped inline. Still the same
/// underlying spontaneous beng feature (FR-SPN-01 through 20) — this is a
/// landing-page restructure, not a new backend.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.isDriverVerified,
    required this.onSearchRides,
    required this.onGoOnline,
    required this.onRequireDriverVerification,
  });

  final bool isDriverVerified;
  final ValueChanged<LeaveWithinOption> onSearchRides;
  final void Function(int seats, int pricePerPassenger, int activeMinutes) onGoOnline;
  final VoidCallback onRequireDriverVerification;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BengMapPlaceholder(height: 160),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Beng!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navyText)),
                const SizedBox(height: 6),
                const Text(
                  'Find quick matching friends immediately! Skip the schedule — match with someone heading your way right now.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.mutedText, height: 1.4),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _QuickBengButton(
                          label: 'Add a Quick Beng',
                          sublabel: 'Offer a ride right now',
                          icon: Icons.directions_car_filled_outlined,
                          background: AppColors.primaryBlue,
                          foreground: Colors.white,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AddQuickBengScreen(
                              isDriverVerified: isDriverVerified,
                              onGoOnline: onGoOnline,
                              onRequireVerification: onRequireDriverVerification,
                            ),
                          )),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _QuickBengButton(
                          label: 'Find a Quick Beng',
                          sublabel: 'Get picked up right now',
                          icon: Icons.near_me_outlined,
                          background: AppColors.amber,
                          foreground: AppColors.navyText,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => FindQuickBengScreen(onSearch: onSearchRides),
                          )),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickBengButton extends StatelessWidget {
  const _QuickBengButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Icon(icon, size: 28, color: foreground),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: foreground)),
                  const SizedBox(height: 2),
                  Text(sublabel, style: TextStyle(fontSize: 11.5, color: foreground.withValues(alpha: 0.8))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: foreground.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
