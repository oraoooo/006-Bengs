import 'package:flutter/material.dart';
import '../../../models/leave_within_option.dart';
import '../../../theme/app_colors.dart';

/// FRD §4.5.2 — "Find a ride now" bottom sheet content.
class FindRideSheet extends StatefulWidget {
  const FindRideSheet({
    super.key,
    required this.onSearch,
    this.pickupLabel = 'Current location',
    this.destinationLabel,
    this.onEditPickup,
    this.onEditDestination,
  });

  /// FR-SPN-04 — defaults to GPS, editable via [onEditPickup].
  final String pickupLabel;

  /// Null until the passenger has picked a destination (FR-SPN-04).
  final String? destinationLabel;

  final VoidCallback? onEditPickup;
  final VoidCallback? onEditDestination;

  /// FR-SPN-08 — fires the instant Request Offer for the selected match.
  /// The caller owns the actual search/matching call (FR-SPN-06).
  final ValueChanged<LeaveWithinOption> onSearch;

  @override
  State<FindRideSheet> createState() => _FindRideSheetState();
}

class _FindRideSheetState extends State<FindRideSheet> {
  LeaveWithinOption _selected = LeaveWithinOption.now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocationRow(
          icon: Icons.my_location,
          iconColor: AppColors.iconBlue,
          label: widget.pickupLabel,
          isPlaceholder: false,
          onTap: widget.onEditPickup,
        ),
        const SizedBox(height: 8),
        _LocationRow(
          icon: Icons.flag_outlined,
          iconColor: AppColors.mutedText,
          label: widget.destinationLabel ?? 'Search destination',
          isPlaceholder: widget.destinationLabel == null,
          onTap: widget.onEditDestination,
        ),
        const SizedBox(height: 16),
        const Text(
          'Leave within',
          style: TextStyle(fontSize: 11, color: AppColors.mutedText),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: LeaveWithinOption.values.map((option) {
            final isSelected = option == _selected;
            return ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (_) => setState(() => _selected = option),
              selectedColor: AppColors.primaryBlue,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : AppColors.mutedText,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: isSelected ? AppColors.primaryBlue : const Color(0xFFDDDDDD),
              ),
              shape: const StadiumBorder(),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => widget.onSearch(_selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.navyText,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Search rides', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isPlaceholder,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isPlaceholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E2E2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isPlaceholder ? AppColors.mutedText : AppColors.navyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
