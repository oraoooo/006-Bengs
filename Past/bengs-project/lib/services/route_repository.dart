import '../models/place.dart';
import 'geocoding_service.dart';
import 'route_matching.dart';
import 'supabase_service.dart';

/// Writes RouteMatcher's output to `beng_route`. Kept separate from the
/// pure algorithm (route_matching.dart) so the matching logic itself stays
/// testable without a Supabase session.
///
/// ETAs use real OpenRouteService driving times between consecutive stops
/// when GeocodingService.isConfigured (ORS_API_KEY set), falling back to
/// haversine distance at an assumed average city-driving speed when it
/// isn't configured or a single ORS call fails — a per-leg fallback,
/// not an all-or-nothing one, so one flaky call doesn't wreck the whole
/// route's schedule.
class RouteRepository {
  RouteRepository._();

  static final _client = SupabaseService.client;
  static const _assumedSpeedKmh = 30.0;

  /// BR-09/CLAUDE.md roadmap step 4 — recomputes and overwrites the full
  /// stop list for one beng_daily from scratch. Called after a request is
  /// accepted (a new passenger changes the optimal route), matching the
  /// "10-minute recompute cooldown" mentioned in CLAUDE.md conceptually,
  /// though no debouncing is implemented here yet.
  static Future<void> rebuildRoute(String bengDailyId) async {
    final bengDaily = await _client
        .from('beng_daily')
        .select('date, beng:beng_id(driver_id, origin_name, origin_latitude, origin_longitude, '
            'destination_name, destination_latitude, destination_longitude, max_passenger, depart_time)')
        .eq('id', bengDailyId)
        .single();

    final beng = bengDaily['beng'] as Map<String, dynamic>;
    final driverId = beng['driver_id'] as String;
    final maxPassenger = beng['max_passenger'] as int;
    final date = bengDaily['date'] as String;
    final departTimeStr = beng['depart_time'] as String;

    final origin = GeoPoint(
      name: beng['origin_name'] as String,
      latitude: (beng['origin_latitude'] as num).toDouble(),
      longitude: (beng['origin_longitude'] as num).toDouble(),
    );
    final destinationName = beng['destination_name'] as String?;
    final destination = destinationName == null
        ? null
        : GeoPoint(
            name: destinationName,
            latitude: (beng['destination_latitude'] as num).toDouble(),
            longitude: (beng['destination_longitude'] as num).toDouble(),
          );

    final acceptedRequests = await _client
        .from('request')
        .select('profile_id, origin_name, origin_latitude, origin_longitude, '
            'destination_name, destination_latitude, destination_longitude')
        .eq('beng_daily_id', bengDailyId)
        .eq('status', 'accepted');

    final legs = acceptedRequests.map((r) {
      return PassengerLeg(
        passengerId: r['profile_id'] as String,
        pickup: GeoPoint(
          name: r['origin_name'] as String,
          latitude: (r['origin_latitude'] as num).toDouble(),
          longitude: (r['origin_longitude'] as num).toDouble(),
        ),
        dropoff: GeoPoint(
          name: r['destination_name'] as String,
          latitude: (r['destination_latitude'] as num).toDouble(),
          longitude: (r['destination_longitude'] as num).toDouble(),
        ),
      );
    }).toList();

    final matcher = RouteMatcher(driverId: driverId, origin: origin, destination: destination, maxPassenger: maxPassenger);
    final stops = matcher.build(legs);

    final departParts = departTimeStr.split(':');
    final baseTime = DateTime.parse('${date}T${departParts[0]}:${departParts[1]}:00');

    var cumulativeMinutes = 0.0;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < stops.length; i++) {
      if (i > 0) {
        cumulativeMinutes += await _legMinutes(stops[i - 1].location, stops[i].location);
      }
      final eta = baseTime.add(Duration(minutes: cumulativeMinutes.round()));
      final stop = stops[i];
      rows.add({
        'beng_daily_id': bengDailyId,
        'location_name': stop.location.name,
        'location_latitude': stop.location.latitude,
        'location_longitude': stop.location.longitude,
        'stop_order': i,
        'passenger_id': stop.passengerId,
        'passenger_state': stop.passengerState,
        'eta': eta.toUtc().toIso8601String(),
      });
    }

    await _client.from('beng_route').delete().eq('beng_daily_id', bengDailyId);
    if (rows.isNotEmpty) {
      await _client.from('beng_route').insert(rows);
    }
  }

  /// Real driving minutes between two stops when GeocodingService is
  /// configured, else haversine distance at the assumed city-driving
  /// speed. GeoPoint (route_matching's pure-algorithm type) and Place
  /// (GeocodingService's type) are deliberately separate — the matcher
  /// stays free of any network/API dependency — so this is the one place
  /// that bridges them.
  static Future<double> _legMinutes(GeoPoint from, GeoPoint to) async {
    if (GeocodingService.isConfigured) {
      final estimate = await GeocodingService.route(
        Place(name: from.name, latitude: from.latitude, longitude: from.longitude),
        Place(name: to.name, latitude: to.latitude, longitude: to.longitude),
      );
      if (estimate != null) return estimate.durationMinutes;
    }
    final distanceKm = haversineKm(from, to);
    return (distanceKm / _assumedSpeedKmh) * 60;
  }

  /// The route/stop timeline for one beng_daily, for display (bengs01.pdf's
  /// Departure/Pick-up/Drop-off/Arrival view) — empty until [rebuildRoute]
  /// has run at least once (i.e. at least one request has been accepted).
  static Future<List<Map<String, dynamic>>> getStops(String bengDailyId) {
    return _client
        .from('beng_route')
        .select('location_name, stop_order, passenger_state, eta, passenger:passenger_id(first_name)')
        .eq('beng_daily_id', bengDailyId)
        .order('stop_order');
  }

  /// BR-11 — who the signed-in user can reach on WhatsApp for this ride: the
  /// driver for a passenger, or each accepted passenger for the driver.
  /// Unlike RatingRepository's equivalent, this isn't gated on the ride
  /// being past — coordinating pickup details happens *before* the ride.
  /// WA-01: being paired on the same beng never unlocks WhatsApp by itself —
  /// mutual follow (SOC-01) AND both parties' allow_cool_friends_whatsapp
  /// toggle (PROF-03) are still required. Each returned contact carries
  /// `is_mutual` and `can_whatsapp` so the UI can show a Follow prompt
  /// instead of a text button when they're not yet eligible, per WA-S01.
  static Future<List<Map<String, dynamic>>> getContacts(String bengDailyId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final bengDaily = await _client
        .from('beng_daily')
        .select('beng:beng_id(driver_id, driver:driver_id(id, first_name, phone_number, allow_cool_friends_whatsapp))')
        .eq('id', bengDailyId)
        .single();
    final beng = bengDaily['beng'] as Map<String, dynamic>;
    final driverId = beng['driver_id'] as String;

    List<Map<String, dynamic>> contacts;
    if (driverId == userId) {
      final rows = await _client
          .from('request')
          .select('profile_id, profile:profile_id(id, first_name, phone_number, allow_cool_friends_whatsapp)')
          .eq('beng_daily_id', bengDailyId)
          .eq('status', 'accepted');
      contacts = rows.map((r) => Map<String, dynamic>.from(r['profile'] as Map<String, dynamic>)).toList();
    } else {
      contacts = [Map<String, dynamic>.from(beng['driver'] as Map<String, dynamic>)];
    }
    if (contacts.isEmpty) return contacts;

    final contactIds = contacts.map((c) => c['id'] as String).toList();
    final mutualRows = await _client.from('friend').select('followed_id, is_mutual').eq('profile_id', userId).inFilter('followed_id', contactIds);
    final mutualById = {for (final r in mutualRows) r['followed_id'] as String: r['is_mutual'] as bool};

    final myProfile = await _client.from('profiles').select('allow_cool_friends_whatsapp').eq('id', userId).single();
    final myAllowsWhatsapp = myProfile['allow_cool_friends_whatsapp'] as bool? ?? false;

    for (final contact in contacts) {
      final isMutual = mutualById[contact['id'] as String] ?? false;
      final theirAllowsWhatsapp = contact['allow_cool_friends_whatsapp'] as bool? ?? false;
      contact['is_mutual'] = isMutual;
      contact['can_whatsapp'] = isMutual && theirAllowsWhatsapp && myAllowsWhatsapp;
    }
    return contacts;
  }
}
