enum ScheduleRole { driver, passenger }

/// One row on the Schedule tab — a single day's instance of a beng
/// (`beng_daily`), normalized from whichever source query found it (driver
/// of the `beng`, or an accepted `request` as passenger).
class ScheduleEntry {
  const ScheduleEntry({
    required this.bengDailyId,
    this.bengId,
    required this.date,
    required this.role,
    required this.label,
    required this.originName,
    required this.destinationName,
    required this.departTime,
    this.vehicleLabel,
    this.counterpartName,
    this.passengerNames = const [],
  });

  final String bengDailyId;

  /// Only populated for a driver's own row — needed for BR-10's Delete
  /// action, which soft-deletes the whole recurring beng, not just one day.
  final String? bengId;
  final DateTime date;
  final ScheduleRole role;
  final String? label;
  final String originName;
  final String? destinationName;
  final String departTime;

  /// "Avanza - B 1234 ABC" style, shown for a driver's own row.
  final String? vehicleLabel;

  /// The driver's first name, shown on a passenger's row.
  final String? counterpartName;

  /// Accepted passengers' first names, for a driver's own row — bengs01.pdf
  /// shows a small overlapping avatar stack ("+N") on each of these cards.
  final List<String> passengerNames;
}
