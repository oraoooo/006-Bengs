import 'package:flutter/material.dart';
import '../../services/driver_repository.dart';
import '../../theme/app_colors.dart';
import 'kyc_screen.dart';
import 'vehicle_screen.dart';

/// Entry point for "Go online" while unverified (FR-SPN-16). Routes to
/// whichever driver-onboarding step is actually missing, rather than always
/// restarting at KYC — someone who's already submitted KYC and is just
/// waiting on review, or who's verified but hasn't added a vehicle yet,
/// shouldn't have to redo an earlier step.
class DriverOnboardingGate extends StatelessWidget {
  const DriverOnboardingGate({super.key});

  Future<_OnboardingStep> _resolveStep() async {
    final status = await DriverRepository.getVerificationStatus();
    if (status == null || status == 'not_started' || status == 'rejected') {
      return _OnboardingStep.kyc;
    }
    final hasVehicle = await DriverRepository.hasDefaultVehicle();
    if (!hasVehicle) return _OnboardingStep.vehicle;
    return _OnboardingStep.pendingReview;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OnboardingStep>(
      future: _resolveStep(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        switch (snapshot.data!) {
          case _OnboardingStep.kyc:
            return const KycScreen();
          case _OnboardingStep.vehicle:
            return const VehicleScreen(popToRootOnSave: true);
          case _OnboardingStep.pendingReview:
            return const _PendingReviewScreen();
        }
      },
    );
  }
}

enum _OnboardingStep { kyc, vehicle, pendingReview }

class _PendingReviewScreen extends StatelessWidget {
  const _PendingReviewScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Verification'), backgroundColor: Colors.white, foregroundColor: AppColors.navyText, elevation: 0),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top, size: 48, color: AppColors.mutedText),
              SizedBox(height: 16),
              Text(
                "Your KYC submission and vehicle are on file and waiting for "
                "review. You'll be able to go online as a driver once approved.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
