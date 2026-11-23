import '../models/schedule_entry.dart';
import '../utils/vehicle_display.dart';
import 'supabase_service.dart';

/// Data access for the Schedule tab (the old calendar/list Home from
/// bengs01.pdf, unchanged content — see CLAUDE.md). Combines two sources
/// into one list: bengs the user drives, and bengs they've been accepted
/// onto as a passenger.
class ScheduleRepository {
  ScheduleRepository._();

  static final _client = SupabaseService.client;

  static String get _requiredUserId {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('ScheduleRepository called with no authenticated user');
    }
    return userId;
  }

  static Future<List<ScheduleEntry>> getUpcoming() => _get(past: false);

  /// Completed rides — the only entry point into rating a ride (there's no
  /// "completed" flag in the schema, so "date already happened" is the
  /// proxy used here and by RouteTimelineScreen's rating section).
  static Future<List<ScheduleEntry>> getPast() => _get(past: true);

  static Future<List<ScheduleEntry>> _get({required bool past}) async {
    final userId = _requiredUserId;
    final today = DateTime.now();
    final todayIso = DateTime(today.year, today.month, today.day).toIso8601String().split('T').first;

    var driverQuery = _client
        .from('beng_daily')
        .select(
          'id, date, cancelled_at, '
          'beng!inner(id, label, origin_name, destination_name, depart_time, driver_id, status, deleted_at, '
          'vehicle:vehicle_id(brand:brand_id(name), model:model_id(name), vehicle_brand_other, vehicle_model_other, vehicle_license_plate))',
        )
        .eq('beng.driver_id', userId)
        .eq('beng.status', true)
        .filter('beng.deleted_at', 'is', null)
        .filter('cancelled_at', 'is', null);
    driverQuery = past ? driverQuery.lt('date', todayIso) : driverQuery.gte('date', todayIso);
    final driverRows = await driverQuery.order('date', ascending: !past);

    // One batched lookup for every driver row's accepted passengers, rather
    // than a query per card — bengs01.pdf's Schedule cards show a small
    // avatar stack of who's actually on each ride.
    final bengDailyIds = driverRows.map((row) => row['id'] as String).toList();
    final passengersByBengDaily = <String, List<String>>{};
    if (bengDailyIds.isNotEmpty) {
      final acceptedRows = await _client
          .from('request')
          .select('beng_daily_id, profile:profile_id(first_name)')
          .inFilter('beng_daily_id', bengDailyIds)
          .eq('status', 'accepted');
      for (final row in acceptedRows) {
        final name = (row['profile'] as Map<String, dynamic>?)?['first_name'] as String?;
        if (name == null) continue;
        passengersByBengDaily.putIfAbsent(row['beng_daily_id'] as String, () => []).add(name);
      }
    }

    final driverEntries = driverRows.map((row) {
      final beng = row['beng'] as Map<String, dynamic>;
      final vehicle = beng['vehicle'] as Map<String, dynamic>?;
      final brandModel = vehicleBrandModelLabel(vehicle);
      final plate = vehicle?['vehicle_license_plate'] as String?;
      return ScheduleEntry(
        bengDailyId: row['id'] as String,
        bengId: beng['id'] as String,
        date: DateTime.parse(row['date'] as String),
        role: ScheduleRole.driver,
        label: beng['label'] as String?,
        originName: beng['origin_name'] as String,
        destinationName: beng['destination_name'] as String?,
        departTime: (beng['depart_time'] as String).substring(0, 5),
        vehicleLabel: (brandModel != null && plate != null) ? '$brandModel - $plate' : plate,
        passengerNames: passengersByBengDaily[row['id'] as String] ?? const [],
      );
    });

    // Accepted requests are how a passenger ends up on a beng_daily —
    // beng_route (the actual per-stop assignment) only gets built once a
    // request is accepted (see RouteRepository.rebuildRoute), so this is
    // the right source to read a passenger's own schedule from.
    final passengerRows = await _client
        .from('request')
        .select(
          'beng_daily:beng_daily_id(id, date, cancelled_at, '
          'beng:beng_id(label, origin_name, destination_name, depart_time, status, deleted_at, '
          'driver:driver_id(first_name)))',
        )
        .eq('profile_id', userId)
        .eq('status', 'accepted');

    final passengerEntries = passengerRows
        .map((row) => row['beng_daily'] as Map<String, dynamic>?)
        .where((bengDaily) => bengDaily != null && bengDaily['cancelled_at'] == null)
        .map((bengDaily) {
          final beng = bengDaily!['beng'] as Map<String, dynamic>;
          final driver = beng['driver'] as Map<String, dynamic>?;
          return ScheduleEntry(
            bengDailyId: bengDaily['id'] as String,
            date: DateTime.parse(bengDaily['date'] as String),
            role: ScheduleRole.passenger,
            label: beng['label'] as String?,
            originName: beng['origin_name'] as String,
            destinationName: beng['destination_name'] as String?,
            departTime: (beng['depart_time'] as String).substring(0, 5),
            counterpartName: driver?['first_name'] as String?,
          );
        })
        .where((entry) {
          final isBeforeToday = entry.date.isBefore(DateTime(today.year, today.month, today.day));
          return past ? isBeforeToday : !isBeforeToday;
        });

    final all = [...driverEntries, ...passengerEntries];
    all.sort((a, b) => past ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    return all;
  }
}
