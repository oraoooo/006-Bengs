import '../models/beng_listing.dart';
import '../utils/vehicle_display.dart';
import 'supabase_service.dart';

/// Data access for Find-a-Beng / Search-the-Bengs — browsing *scheduled*
/// bengs (as opposed to the spontaneous ones the Home tab searches).
class BengSearchRepository {
  BengSearchRepository._();

  static final _client = SupabaseService.client;

  /// One row per `beng`, taken as its nearest upcoming `beng_daily`
  /// instance — that's the actual unit a passenger requests to join.
  static Future<List<BengListing>> searchScheduled({String? query}) async {
    final userId = SupabaseService.currentUser?.id;
    final todayIso = DateTime.now().toIso8601String().split('T').first;

    List<dynamic> bengRows;
    try {
      bengRows = await _client
          .from('beng')
          .select(
            'id, label, origin_name, origin_latitude, origin_longitude, '
            'destination_name, destination_latitude, destination_longitude, '
            'depart_time, price, max_passenger, driver_id, '
            'driver:driver_id(first_name, driver_rating), '
            'vehicle:vehicle_id(brand:brand_id(name), model:model_id(name), vehicle_brand_other, vehicle_model_other, vehicle_license_plate)',
          )
          .eq('mode', 'scheduled')
          .eq('status', true)
          .filter('deleted_at', 'is', null);
    } catch (_) {
      bengRows = await _client
          .from('beng')
          .select(
            'id, label, origin_name, origin_latitude, origin_longitude, '
            'destination_name, destination_latitude, destination_longitude, '
            'depart_time, price, max_passenger, driver_id',
          )
          .eq('mode', 'scheduled')
          .eq('status', true)
          .filter('deleted_at', 'is', null);
    }

    final dailyRows = await _client
        .from('beng_daily')
        .select('id, date, beng_id')
        .filter('cancelled_at', 'is', null)
        .gte('date', todayIso)
        .order('date');

    final nearestDaily = <String, Map<String, dynamic>>{};
    for (final row in dailyRows) {
      final bengId = row['beng_id'] as String;
      nearestDaily.putIfAbsent(bengId, () => row);
    }

    final listings = <BengListing>[];
    for (final beng in bengRows) {
      final bengId = beng['id'] as String;
      final daily = nearestDaily[bengId];
      if (daily == null) continue;

      final driver = beng['driver'];
      final driverMap = driver is Map<String, dynamic> ? driver : null;
      final vehicle = beng['vehicle'];
      final vehicleMap = vehicle is Map<String, dynamic> ? vehicle : null;
      final brandModel = vehicleBrandModelLabel(vehicleMap);
      final plate = vehicleMap?['vehicle_license_plate'] as String?;
      final driverId = beng['driver_id'] as String?;

      listings.add(BengListing(
        bengDailyId: daily['id'] as String,
        bengId: bengId,
        date: DateTime.parse(daily['date'] as String),
        label: beng['label'] as String?,
        originName: beng['origin_name'] as String,
        originLatitude: (beng['origin_latitude'] as num).toDouble(),
        originLongitude: (beng['origin_longitude'] as num).toDouble(),
        destinationName: beng['destination_name'] as String?,
        destinationLatitude: (beng['destination_latitude'] as num?)?.toDouble(),
        destinationLongitude: (beng['destination_longitude'] as num?)?.toDouble(),
        departTime: (beng['depart_time'] as String).substring(0, 5),
        price: beng['price'] as int,
        maxPassenger: beng['max_passenger'] as int,
        driverName: (driverMap?['first_name'] as String?) ?? 'Driver',
        driverRating: (driverMap?['driver_rating'] as num?)?.toDouble(),
        vehicleLabel: (brandModel != null && plate != null) ? '$brandModel - $plate' : plate,
        isOwn: userId != null && driverId == userId,
      ));
    }

    listings.sort((a, b) => a.date.compareTo(b.date));

    if (query == null || query.trim().isEmpty) return listings;
    final q = query.trim().toLowerCase();
    return listings.where((l) {
      return (l.label?.toLowerCase().contains(q) ?? false) ||
          l.originName.toLowerCase().contains(q) ||
          (l.destinationName?.toLowerCase().contains(q) ?? false) ||
          l.driverName.toLowerCase().contains(q);
    }).toList();
  }
}
