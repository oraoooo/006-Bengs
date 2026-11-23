import 'supabase_service.dart';

/// BR-10 — Cancel and Delete are distinct actions from Reject (handled in
/// RequestRepository), each with their own UI and semantics:
/// - Cancel unwinds an already-accepted day, needs a reason, and cascades
///   to every passenger already accepted onto it (they get notified — see
///   the notify_request_status_change trigger).
/// - Delete removes a beng's entire recurring series outright (soft
///   delete via beng.deleted_at, already filtered out everywhere else).
class BengManagementRepository {
  BengManagementRepository._();

  static final _client = SupabaseService.client;

  static Future<void> cancelDay(String bengDailyId, String reason) async {
    await _client.from('beng_daily').update({
      'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      'cancel_reason': reason,
    }).eq('id', bengDailyId);

    await _client
        .from('request')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          'cancel_reason': reason,
        })
        .eq('beng_daily_id', bengDailyId)
        .eq('status', 'accepted');
  }

  static Future<void> deleteBeng(String bengId, String reason) async {
    await _client.from('beng').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      'delete_reason': reason,
      'status': false,
    }).eq('id', bengId);
  }
}
