import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// FRD §4.5.3 — "Offer a ride now" bottom sheet content.
class OfferRideSheet extends StatefulWidget {
  const OfferRideSheet({
    super.key,
    required this.isDriverVerified,
    required this.onGoOnline,
    required this.onRequireVerification,
    this.initialSeats = 2,
    this.initialPricePerPassenger = 5000,
    this.initialActiveMinutes = 60,
  });

  /// FR-SPN-16 — "Offer a ride" stays disabled until driverVerification
  /// status is 'verified' (BR-03/BR-04). Passed in rather than looked up
  /// here so this widget stays free of auth/data concerns.
  final bool isDriverVerified;

  final void Function(int seats, int pricePerPassenger, int activeMinutes) onGoOnline;

  /// FR-SPN-16 — tapping while unverified opens the KYC flow instead.
  final VoidCallback onRequireVerification;

  final int initialSeats;
  final int initialPricePerPassenger;
  final int initialActiveMinutes;

  @override
  State<OfferRideSheet> createState() => _OfferRideSheetState();
}

class _OfferRideSheetState extends State<OfferRideSheet> {
  // NOTE: these can't be initialized inline at declaration (`= widget.x`)
  // because `widget` isn't attached yet when field initializers run —
  // Flutter sets it after construction, right before initState(). Assigning
  // in initState() is the correct, safe place to read the initial widget.
  late int _seats;
  late int _pricePerPassenger;
  late int _activeMinutes;

  @override
  void initState() {
    super.initState();
    _seats = widget.initialSeats;
    _pricePerPassenger = widget.initialPricePerPassenger;
    _activeMinutes = widget.initialActiveMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingRow(
          label: 'Seats available',
          child: _Stepper(
            value: _seats,
            min: 1,
            max: 6,
            onChanged: (v) => setState(() => _seats = v),
          ),
        ),
        const SizedBox(height: 8),
        _SettingRow(
          label: 'Price per passenger',
          child: _Stepper(
            value: _pricePerPassenger,
            min: 0,
            max: 100000,
            step: 1000,
            format: (v) => 'Rp $v',
            onChanged: (v) => setState(() => _pricePerPassenger = v),
          ),
        ),
        const SizedBox(height: 8),
        _SettingRow(
          label: 'Active until',
          // FR-SPN-14 — offer auto-expires if unused; default 60 min.
          child: _Stepper(
            value: _activeMinutes,
            min: 15,
            max: 180,
            step: 15,
            format: (v) => '$v min',
            onChanged: (v) => setState(() => _activeMinutes = v),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.isDriverVerified
                ? () => widget.onGoOnline(_seats, _pricePerPassenger, _activeMinutes)
                : widget.onRequireVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Go online', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        if (!widget.isDriverVerified) ...[
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 13, color: AppColors.mutedText),
              SizedBox(width: 4),
              Text(
                'Requires driver verification',
                style: TextStyle(fontSize: 10.5, color: AppColors.mutedText),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E2E2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.navyText)),
          child,
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.format,
  });

  final int value;
  final int min;
  final int max;
  final int step;
  final String Function(int)? format;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove,
          onTap: value > min ? () => onChanged(value - step) : null,
        ),
        SizedBox(
          width: 56,
          child: Text(
            format?.call(value) ?? '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.navyText,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          onTap: value < max ? () => onChanged(value + step) : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDDDDDD)),
        ),
        child: Icon(
          icon,
          size: 13,
          color: onTap == null ? Colors.grey.shade300 : AppColors.primaryBlue,
        ),
      ),
    );
  }
}
