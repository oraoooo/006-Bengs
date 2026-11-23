import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'widgets/offer_ride_sheet.dart';

/// "add a quick beng" per bengs Draft.pdf's ADDITIONAL FEEDBACK section —
/// same shape as the existing spontaneous "Offer a ride" form
/// (OfferRideSheet), just as its own full-bleed blue page rather than a
/// mode inside a toggle, matching the doc's "(would show -> mostly blue,
/// slide right to left)". Departure location/time are already forced to
/// "now, current location" by goOnline() itself — nothing to add there.
///
/// The doc's next step — confirming goes into a dark "finding cool
/// people..." queue you swipe through one match at a time — is real UX
/// design work with no backend behind it yet (spontaneous requests have no
/// live queue, no "cool person" matching signal). Deliberately not built
/// here per scope: this screen is the prep, not the matching engine.
class AddQuickBengScreen extends StatelessWidget {
  const AddQuickBengScreen({
    super.key,
    required this.isDriverVerified,
    required this.onGoOnline,
    required this.onRequireVerification,
  });

  final bool isDriverVerified;
  final void Function(int seats, int pricePerPassenger, int activeMinutes) onGoOnline;
  final VoidCallback onRequireVerification;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add a Quick Beng'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: OfferRideSheet(
              isDriverVerified: isDriverVerified,
              onGoOnline: onGoOnline,
              onRequireVerification: onRequireVerification,
            ),
          ),
        ),
      ),
    );
  }
}
