/// FR-SPN-05 — how soon the passenger wants to leave.
///
/// Exact preset values are still an open question in the FRD (§4.9) — these
/// four are the proposed defaults. Changing them only touches this file.
enum LeaveWithinOption {
  now,
  fifteenMinutes,
  thirtyMinutes,
  oneHour;

  String get label {
    switch (this) {
      case LeaveWithinOption.now:
        return 'Now';
      case LeaveWithinOption.fifteenMinutes:
        return '15 min';
      case LeaveWithinOption.thirtyMinutes:
        return '30 min';
      case LeaveWithinOption.oneHour:
        return '1 hr';
    }
  }
}
