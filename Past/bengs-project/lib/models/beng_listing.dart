/// One bookable scheduled beng — specifically, its nearest upcoming
/// beng_daily instance, since that's the unit a `request` row is filed
/// against (not the recurring `beng` itself).
class BengListing {
  const BengListing({
    required this.bengDailyId,
    required this.bengId,
    required this.date,
    required this.label,
    required this.originName,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.departTime,
    required this.price,
    required this.maxPassenger,
    required this.driverName,
    this.driverRating,
    this.vehicleLabel,
    this.isOwn = false,
  });

  final String bengDailyId;
  final String bengId;
  final DateTime date;
  final String? label;
  final String originName;
  final double originLatitude;
  final double originLongitude;
  final String? destinationName;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String departTime;
  final int price;
  final int maxPassenger;
  final String driverName;
  final double? driverRating;
  final String? vehicleLabel;
  final bool isOwn;
}
