import 'supabase_service.dart';

/// Data access for the ratings/review screens — submitting a rating for a
/// specific completed beng_daily (never floating free of a ride, per the
/// schema's uniqueness constraint on (rater, rated, beng_daily)).
class RatingRepository {
  RatingRepository._();

  static final _client = SupabaseService.client;

  static String get _requiredUserId {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('RatingRepository called with no authenticated user');
    }
    return userId;
  }

  /// A passenger rating the driver of a completed ride.
  static Future<void> rateDriver({
    required String bengDailyId,
    required String driverId,
    required double score,
    String? review,
  }) async {
    await _client.from('driver_rating').insert({
      'profile_id': _requiredUserId,
      'rated_id': driverId,
      'beng_daily_id': bengDailyId,
      'score': score,
      'review': review,
    });
  }

  /// The driver rating one of their passengers on a completed ride.
  static Future<void> ratePassenger({
    required String bengDailyId,
    required String passengerId,
    required double score,
    String? review,
  }) async {
    await _client.from('passenger_rating').insert({
      'profile_id': _requiredUserId,
      'rated_id': passengerId,
      'beng_daily_id': bengDailyId,
      'score': score,
      'review': review,
    });
  }

  static Future<bool> hasRatedDriver(String bengDailyId, String driverId) async {
    final row = await _client
        .from('driver_rating')
        .select('id')
        .eq('profile_id', _requiredUserId)
        .eq('rated_id', driverId)
        .eq('beng_daily_id', bengDailyId)
        .maybeSingle();
    return row != null;
  }

  static Future<bool> hasRatedPassenger(String bengDailyId, String passengerId) async {
    final row = await _client
        .from('passenger_rating')
        .select('id')
        .eq('profile_id', _requiredUserId)
        .eq('rated_id', passengerId)
        .eq('beng_daily_id', bengDailyId)
        .maybeSingle();
    return row != null;
  }

  /// The people the signed-in user could rate for this beng_daily: the
  /// other side of the ride from their own role. A passenger rates the
  /// driver; a driver rates their accepted passengers.
  static Future<RateableCounterparts> getRateableCounterparts(String bengDailyId) async {
    final userId = _requiredUserId;

    final bengDaily = await _client
        .from('beng_daily')
        .select('beng:beng_id(driver_id, driver:driver_id(first_name))')
        .eq('id', bengDailyId)
        .single();
    final beng = bengDaily['beng'] as Map<String, dynamic>;
    final driverId = beng['driver_id'] as String;
    final amDriver = driverId == userId;

    if (amDriver) {
      final rows = await _client
          .from('request')
          .select('profile_id, profile:profile_id(first_name)')
          .eq('beng_daily_id', bengDailyId)
          .eq('status', 'accepted');
      final people = rows
          .map((r) => {'id': r['profile_id'] as String, 'first_name': (r['profile'] as Map<String, dynamic>?)?['first_name'] as String?})
          .toList();
      return RateableCounterparts(amDriver: true, people: people);
    }

    final driver = beng['driver'] as Map<String, dynamic>?;
    return RateableCounterparts(amDriver: false, people: [
      {'id': driverId, 'first_name': driver?['first_name'] as String?},
    ]);
  }
}

/// Who the signed-in user can rate for one beng_daily, and which table
/// their submission needs to go into.
class RateableCounterparts {
  const RateableCounterparts({required this.amDriver, required this.people});

  final bool amDriver;
  final List<Map<String, String?>> people;
}
