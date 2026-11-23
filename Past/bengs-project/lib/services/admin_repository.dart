import 'supabase_service.dart';

/// Data access for the admin driver/vehicle review screen — gated by
/// `profiles.is_admin`, which nothing in the app sets on its own (flip it
/// by hand in Supabase for whichever account should be able to review).
/// See 20260904000300_admin_review.sql for the RLS this depends on.
class AdminRepository {
  AdminRepository._();

  static final _client = SupabaseService.client;

  static Future<bool> isCurrentUserAdmin() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;
    final row = await _client.from('profiles').select('is_admin').eq('id', userId).maybeSingle();
    return row?['is_admin'] == true;
  }

  static Future<List<Map<String, dynamic>>> getPendingDriverVerifications() async {
    return _client
        .from('driver_verification')
        .select('id, profile_id, ktp_full_name, id_number, ktp_date_of_birth, ktp_gender, address, '
            'province, city, district, village, postcode, id_card_photo_url, id_card_selfie_url, submitted_at, '
            'profile:profile_id(first_name, surname)')
        .eq('status', 'pending')
        .order('submitted_at');
  }

  static Future<List<Map<String, dynamic>>> getPendingVehicles() async {
    return _client
        .from('vehicle')
        .select('id, profile_id, vehicle_type, brand:brand_id(name), model:model_id(name), '
            'vehicle_brand_other, vehicle_model_other, vehicle_license_plate, '
            'vehicle_registration_cert_url, created_at, profile:profile_id(first_name, surname)')
        .eq('is_verified', false)
        .order('created_at');
  }

  /// Both photo fields live in the private `driver-documents` bucket under
  /// the uploader's own uid — an admin needs a short-lived signed URL to
  /// view them, since the bucket has no public read access at all.
  static Future<String> signedDocumentUrl(String path) async {
    final url = await _client.storage.from('driver-documents').createSignedUrl(path, 300);
    return url;
  }

  static Future<void> approveDriverVerification(String verificationId) async {
    await _client.from('driver_verification').update({
      'status': 'verified',
      'verified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', verificationId);
  }

  static Future<void> rejectDriverVerification(String verificationId, String reason) async {
    await _client.from('driver_verification').update({
      'status': 'rejected',
      'rejected_reason': reason,
    }).eq('id', verificationId);
  }

  static Future<void> approveVehicle(String vehicleId) async {
    await _client.from('vehicle').update({
      'is_verified': true,
      'verified_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', vehicleId);
  }

  static Future<void> rejectVehicle(String vehicleId, String reason) async {
    await _client.from('vehicle').update({'reject_reason': reason}).eq('id', vehicleId);
  }
}
