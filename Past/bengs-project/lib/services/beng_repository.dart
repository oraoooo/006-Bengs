import '../models/leave_within_option.dart';
import '../models/repeat_rule.dart';
import 'supabase_service.dart';

/// Data access for the `beng`/`beng_daily`/`request` tables, scoped to what
/// the spontaneous Home tab needs (FR-SPN-06, FR-SPN-12). Screens stay pure
/// UI and call through here rather than touching Supabase directly.
class BengRepository {
  BengRepository._();

  static final _client = SupabaseService.client;

  /// FR-SPN-06 — spontaneous rides currently open for matching.
  ///
  /// [leaveWithin] narrows by how soon the passenger wants to leave; `now`
  /// is treated as "no filter" so the freshest offers surface first.
  static Future<List<Map<String, dynamic>>> searchSpontaneousRides(
    LeaveWithinOption leaveWithin,
  ) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    var query = _client
        .from('beng')
        .select()
        .eq('mode', 'spontaneous')
        .eq('status', true)
        .filter('deleted_at', 'is', null);

    if (leaveWithin != LeaveWithinOption.now) {
      final cutoff = DateTime.now().add(_windowFor(leaveWithin)).toUtc();
      query = query.gte('expires_at', nowIso).lte('expires_at', cutoff.toIso8601String());
    } else {
      query = query.gte('expires_at', nowIso);
    }

    return query.order('created_at', ascending: false);
  }

  static Duration _windowFor(LeaveWithinOption option) {
    switch (option) {
      case LeaveWithinOption.now:
        return Duration.zero;
      case LeaveWithinOption.fifteenMinutes:
        return const Duration(minutes: 15);
      case LeaveWithinOption.thirtyMinutes:
        return const Duration(minutes: 30);
      case LeaveWithinOption.oneHour:
        return const Duration(hours: 1);
    }
  }

  /// FR-SPN-12/14 — driver goes online with an open-destination spontaneous
  /// offer that auto-expires after [activeMinutes].
  ///
  /// Origin is a placeholder until real geolocation replaces
  /// [BengMapPlaceholder] (see lib/widgets/beng_map_placeholder.dart) — swap
  /// the TODO below out at the same time.
  static Future<String> goOnline({
    required int seats,
    required int pricePerPassenger,
    required int activeMinutes,
  }) async {
    final driverId = SupabaseService.currentUser?.id;
    if (driverId == null) {
      throw StateError('goOnline called with no authenticated user');
    }

    final vehicle = await _client
        .from('vehicle')
        .select('id')
        .eq('profile_id', driverId)
        .eq('is_default', true)
        .maybeSingle();
    if (vehicle == null) {
      throw StateError('No default vehicle on file — add a vehicle before going online');
    }

    final now = DateTime.now();
    // TODO(geolocation): read the driver's real GPS position once
    // BengMapPlaceholder is replaced with a live map widget.
    const originName = 'Current location';
    const originLat = -6.2088;
    const originLng = 106.8456;

    final beng = await _client
        .from('beng')
        .insert({
          'driver_id': driverId,
          'vehicle_id': vehicle['id'],
          'mode': 'spontaneous',
          'origin_name': originName,
          'origin_latitude': originLat,
          'origin_longitude': originLng,
          'price': pricePerPassenger,
          'max_passenger': seats,
          'depart_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00',
          'start_date': now.toIso8601String().split('T').first,
          'expires_at': now.add(Duration(minutes: activeMinutes)).toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final bengId = beng['id'] as String;
    await _client.from('beng_daily').insert({
      'beng_id': bengId,
      'date': now.toIso8601String().split('T').first,
    });

    return bengId;
  }

  /// Add-a-Beng — [vehicleId] must be one of the caller's own saved
  /// vehicles (BR-06's explicit Motor/Mobil selector picks from these,
  /// rather than silently falling back to whichever is flagged default).
  /// [repeat] drives how many beng_daily rows get created up front — see
  /// RepeatRule.occurrences for the generation window/cap.
  static Future<String> createScheduledBeng({
    String? label,
    required String vehicleId,
    required String originName,
    required double originLatitude,
    required double originLongitude,
    required String destinationName,
    required double destinationLatitude,
    required double destinationLongitude,
    required int price,
    required int maxPassenger,
    required DateTime departDateTime,
    RepeatRule repeat = const RepeatRule(),
  }) async {
    final driverId = SupabaseService.currentUser?.id;
    if (driverId == null) {
      throw StateError('createScheduledBeng called with no authenticated user');
    }

    final dateOnly = departDateTime.toIso8601String().split('T').first;
    final timeOnly =
        '${departDateTime.hour.toString().padLeft(2, '0')}:${departDateTime.minute.toString().padLeft(2, '0')}:00';

    final beng = await _client
        .from('beng')
        .insert({
          'driver_id': driverId,
          'vehicle_id': vehicleId,
          'mode': 'scheduled',
          'label': label,
          'origin_name': originName,
          'origin_latitude': originLatitude,
          'origin_longitude': originLongitude,
          'destination_name': destinationName,
          'destination_latitude': destinationLatitude,
          'destination_longitude': destinationLongitude,
          'price': price,
          'max_passenger': maxPassenger,
          'depart_time': timeOnly,
          'start_date': dateOnly,
          ...repeat.toBengFields(),
        })
        .select('id')
        .single();

    final bengId = beng['id'] as String;
    final occurrences = repeat.occurrences(startDate: departDateTime);
    await _client.from('beng_daily').insert([
      for (final date in occurrences) {'beng_id': bengId, 'date': date.toIso8601String().split('T').first},
    ]);

    return bengId;
  }
}
