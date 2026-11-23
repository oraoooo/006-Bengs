import 'supabase_service.dart';

/// Data access for the Friends tab — following other BENGS users
/// (`friend` table). There's no mutual "friend request" step in the
/// schema; it's a one-directional follow, same shape as the `block` table.
class FriendRepository {
  FriendRepository._();

  static final _client = SupabaseService.client;

  static String get _requiredUserId {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('FriendRepository called with no authenticated user');
    }
    return userId;
  }

  /// Includes is_mutual and the followed profile's own WhatsApp toggle —
  /// WA-01's gate needs both of those plus the signed-in user's own toggle
  /// (ProfileRepository.getMyAllowCoolFriendsWhatsapp) before a "Text in
  /// WhatsApp" button may ever be shown; being followed one-directionally
  /// is not enough on its own.
  static Future<List<Map<String, dynamic>>> getMyFriends() async {
    final rows = await _client
        .from('friend')
        .select('is_mutual, followed:followed_id(id, first_name, surname, driver_rating, passenger_rating, '
            'phone_number, allow_cool_friends_whatsapp)')
        .eq('profile_id', _requiredUserId);
    return rows.map((row) {
      final followed = Map<String, dynamic>.from(row['followed'] as Map<String, dynamic>);
      followed['is_mutual'] = row['is_mutual'];
      return followed;
    }).toList();
  }

  /// Excludes the signed-in user themself from results.
  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final userId = _requiredUserId;
    if (query.trim().isEmpty) return [];
    final rows = await _client
        .from('profiles')
        .select('id, first_name, surname, driver_rating, passenger_rating, phone_number')
        .ilike('first_name', '%${query.trim()}%')
        .neq('id', userId)
        .limit(20);
    return rows;
  }

  static Future<Set<String>> getMyFollowedIds() async {
    final rows = await _client.from('friend').select('followed_id').eq('profile_id', _requiredUserId);
    return rows.map((row) => row['followed_id'] as String).toSet();
  }

  static Future<void> follow(String followedId) async {
    await _client.from('friend').insert({'profile_id': _requiredUserId, 'followed_id': followedId});
  }

  static Future<void> unfollow(String followedId) async {
    await _client.from('friend').delete().eq('profile_id', _requiredUserId).eq('followed_id', followedId);
  }
}
