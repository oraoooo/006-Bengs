import '../models/beng_listing.dart';
import 'supabase_service.dart';

/// Data access for a passenger's join requests against a scheduled beng
/// (the `request` table). Acceptance/rejection is the driver-side
/// "Reviewing" flow from bengs01.pdf — see ReviewingScreen.
class RequestRepository {
  RequestRepository._();

  static final _client = SupabaseService.client;

  static String get _requiredUserId {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('RequestRepository called with no authenticated user');
    }
    return userId;
  }

  /// Null if the signed-in user has never requested this beng_daily.
  static Future<String?> getMyRequestStatus(String bengDailyId) async {
    final row = await _client
        .from('request')
        .select('status')
        .eq('beng_daily_id', bengDailyId)
        .eq('profile_id', _requiredUserId)
        .maybeSingle();
    return row?['status'] as String?;
  }

  /// bengs01.pdf's Notification screen's "Your Request" section — the
  /// passenger's own outstanding requests. Before this there was no page
  /// anywhere that listed these in aggregate; the only way to see one was
  /// to revisit that exact beng's BengDetailScreen from Find-a-Beng again.
  static Future<List<Map<String, dynamic>>> getMyPendingRequests() async {
    final rows = await _client
        .from('request')
        .select(
          'id, origin_name, destination_name, depart_time, created_at, response_deadline, '
          'beng_daily:beng_daily_id!inner(date, beng:beng_id!inner(label, driver:driver_id(first_name)))',
        )
        .eq('profile_id', _requiredUserId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return rows;
  }

  /// BR-10 — the driver-side "Reviewing" list: pending requests against any
  /// of the signed-in user's own bengs.
  static Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final rows = await _client
        .from('request')
        .select(
          'id, beng_daily_id, origin_name, destination_name, depart_time, created_at, '
          'profile:profile_id(first_name, surname, passenger_rating), '
          'beng_daily:beng_daily_id!inner(date, beng:beng_id!inner(label, driver_id))',
        )
        .eq('status', 'pending')
        .eq('beng_daily.beng.driver_id', _requiredUserId)
        .order('created_at');
    return rows;
  }

  /// BR-10 — Accept/Reject are distinct actions with no reason required for
  /// either (unlike Cancel, which unwinds an already-accepted deal and does
  /// need one — not implemented here, that's a Schedule-tab action).
  static Future<void> respondToRequest(String requestId, {required bool accept}) async {
    await _client.from('request').update({'status': accept ? 'accepted' : 'rejected'}).eq('id', requestId);
  }

  /// Undoes an Accept that turned out to be infeasible — RouteRepository.
  /// rebuildRoute throwing RouteCapacityExceededException means the vehicle
  /// is already full through every span of the route, so the request must
  /// not be left sitting at 'accepted' with no route ever computed for it.
  static Future<void> revertToPending(String requestId) async {
    await _client.from('request').update({'status': 'pending'}).eq('id', requestId);
  }

  /// Requests to join at the beng's own default pickup/drop-off points and
  /// time — asking for a custom pickup point along the route is a
  /// fast-follow, not part of this first pass.
  static Future<void> requestToJoin(BengListing listing) async {
    await _client.from('request').insert({
      'beng_daily_id': listing.bengDailyId,
      'profile_id': _requiredUserId,
      'mode': 'scheduled',
      'origin_name': listing.originName,
      'origin_latitude': listing.originLatitude,
      'origin_longitude': listing.originLongitude,
      'destination_name': listing.destinationName ?? listing.originName,
      'destination_latitude': listing.destinationLatitude ?? listing.originLatitude,
      'destination_longitude': listing.destinationLongitude ?? listing.originLongitude,
      'depart_time': '${listing.departTime}:00',
    });
  }
}
