import 'supabase_service.dart';

/// Data access for the Inbox tab (`notification` table).
class NotificationRepository {
  NotificationRepository._();

  static final _client = SupabaseService.client;

  static String get _requiredUserId {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('NotificationRepository called with no authenticated user');
    }
    return userId;
  }

  static Future<List<Map<String, dynamic>>> getMyNotifications() async {
    return _client
        .from('notification')
        .select()
        .eq('profile_id', _requiredUserId)
        .order('created_at', ascending: false);
  }

  static Future<int> getUnreadCount() async {
    final rows = await _client
        .from('notification')
        .select('id')
        .eq('profile_id', _requiredUserId)
        .eq('is_read', false);
    return rows.length;
  }

  static Future<void> markAsRead(String id) async {
    await _client.from('notification').update({'is_read': true}).eq('id', id);
  }
}
