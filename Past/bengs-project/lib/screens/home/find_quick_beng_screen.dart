import 'package:flutter/material.dart';
import '../../models/leave_within_option.dart';
import '../../theme/app_colors.dart';
import 'widgets/find_ride_sheet.dart';

/// "find a quick beng" per bengs Draft.pdf's ADDITIONAL FEEDBACK section —
/// same shape as the existing spontaneous "Find a ride" form
/// (FindRideSheet), as its own full-bleed amber page: "(would show ->
/// mostly yellow, slide left to right)".
///
/// Same scope note as AddQuickBengScreen: the doc's actual "cool people"
/// matching queue (swipeable one-at-a-time results, "cool person"/"cool
/// friend" tags) is not built here — this is the entry-point page only.
class FindQuickBengScreen extends StatelessWidget {
  const FindQuickBengScreen({super.key, required this.onSearch});

  final ValueChanged<LeaveWithinOption> onSearch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.amber,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.navyText,
        elevation: 0,
        title: const Text('Find a Quick Beng'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: FindRideSheet(onSearch: onSearch),
          ),
        ),
      ),
    );
  }
}
