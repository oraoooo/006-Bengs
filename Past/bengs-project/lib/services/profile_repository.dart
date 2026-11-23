import 'supabase_service.dart';

/// Data access for the Profile tab and Account/Settings screen.
class ProfileRepository {
  ProfileRepository._();

  static final _client = SupabaseService.client;

  static String get _requiredUserId {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('ProfileRepository called with no authenticated user');
    }
    return userId;
  }

  /// Joins indonesia_region so callers get a resolvable neighbourhood name,
  /// not just a bare neighbourhood_id UUID — see PROF-02: the lookup table
  /// exists but is unpopulated (~83,000-row data import, tracked separately
  /// in FRD §13), so this join legitimately returns null until that import
  /// runs. Callers must not assume it always has data.
  static Future<Map<String, dynamic>> getMyProfile() async {
    return _client
        .from('profiles')
        .select('*, neighbourhood:neighbourhood_id(id, province, city, district, village)')
        .eq('id', _requiredUserId)
        .single();
  }

  /// Cheap standalone read for WA-01's WhatsApp gate — callers need this
  /// alongside the *other* party's toggle and mutual-follow status, and
  /// pulling the full getMyProfile() join just for one boolean would waste
  /// the neighbourhood/vehicle-adjacent joins that call doesn't need here.
  static Future<bool> getMyAllowCoolFriendsWhatsapp() async {
    final row = await _client.from('profiles').select('allow_cool_friends_whatsapp').eq('id', _requiredUserId).single();
    return row['allow_cool_friends_whatsapp'] as bool? ?? false;
  }

  static Future<void> updateProfile({
    required String firstName,
    String? surname,
    String? gender,
    String? phoneNumber,
  }) async {
    await _client.from('profiles').update({
      'first_name': firstName,
      'surname': surname,
      'gender': gender,
      'phone_number': phoneNumber,
    }).eq('id', _requiredUserId);
  }

  /// Prep-only per bengs Draft.pdf's ADDITIONAL FEEDBACK section — stores
  /// the optional "cool person" enrichment fields and their per-field
  /// public/cool-friends visibility, but nothing yet reads
  /// [profileVisibility] to actually gate what other users can see, and no
  /// matching/tagging logic exists. That's separate, unbuilt work.
  static Future<void> updateCoolProfile({
    String? bio,
    List<String> interests = const [],
    String? jobTitle,
    String? workplaceName,
    String? neighbourhoodId,
    String? instagramHandle,
    required Map<String, String> profileVisibility,
    required bool allowCoolFriendsWhatsapp,
  }) async {
    await _client.from('profiles').update({
      'bio': bio,
      'interests': interests,
      'job_title': jobTitle,
      'workplace_name': workplaceName,
      'neighbourhood_id': neighbourhoodId,
      'instagram_handle': instagramHandle,
      'profile_visibility': profileVisibility,
      'allow_cool_friends_whatsapp': allowCoolFriendsWhatsapp,
    }).eq('id', _requiredUserId);
  }

  /// National-scope search against indonesia_region (PROF-02) — the table
  /// is a lookup, not a dropdown source, since it's sized for ~83,000 rows
  /// once populated; matches village/district/city/province by substring.
  /// Returns an empty list for a blank query rather than the whole table.
  static Future<List<Map<String, dynamic>>> searchNeighbourhoods(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final pattern = '%$trimmed%';
    return _client
        .from('indonesia_region')
        .select('id, province, city, district, village')
        .or('village.ilike.$pattern,district.ilike.$pattern,city.ilike.$pattern,province.ilike.$pattern')
        .order('village')
        .limit(20);
  }

  /// Joins the brand/model lookup tables so callers get a resolvable name,
  /// not just a bare brand_id/model_id UUID — vehicleBrandModelLabel() falls
  /// back to vehicle_brand_other/vehicle_model_other when a driver picked
  /// "Other, not listed" and the join comes back null (VEH-01).
  static Future<List<Map<String, dynamic>>> getMyVehicles() async {
    return _client
        .from('vehicle')
        .select('*, brand:brand_id(name), model:model_id(name)')
        .eq('profile_id', _requiredUserId)
        .order('created_at');
  }
}
