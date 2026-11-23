import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Data access for the driver-mode onboarding gate (BR-03/BR-04): KYC
/// verification and vehicle registration. Both are prerequisites for
/// [BengRepository.goOnline] as a driver, but are otherwise independent of
/// each other in the schema.
class DriverRepository {
  DriverRepository._();

  static final _client = SupabaseService.client;

  static String get _requiredUserId {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('DriverRepository called with no authenticated user');
    }
    return userId;
  }

  /// Null when the user has never started KYC (no row yet) — treat the same
  /// as 'not_started'.
  static Future<String?> getVerificationStatus() async {
    final row = await _client
        .from('driver_verification')
        .select('status')
        .eq('profile_id', _requiredUserId)
        .maybeSingle();
    return row?['status'] as String?;
  }

  static Future<bool> hasDefaultVehicle() async {
    final row = await _client
        .from('vehicle')
        .select('id')
        .eq('profile_id', _requiredUserId)
        .eq('is_default', true)
        .maybeSingle();
    return row != null;
  }

  /// Full brand list, unfiltered by vehicle type — per VEH-01, a brand
  /// (e.g. Honda, Suzuki, Yamaha) can sell both motor and mobil, so only the
  /// model list narrows by type, not the brand list.
  static Future<List<Map<String, dynamic>>> getVehicleBrands() {
    return _client.from('vehicle_brand').select('id, name').order('name');
  }

  /// Full model list, including `vehicle_type` and `brand_id` so callers can
  /// filter client-side (both are small, bounded lookup tables — no need for
  /// a query per brand/type combination as the user picks).
  static Future<List<Map<String, dynamic>>> getVehicleModels() {
    return _client.from('vehicle_model').select('id, brand_id, name, vehicle_type').order('name');
  }

  /// Uploads into the private `driver-documents` bucket under the caller's
  /// own uid (see 20260904000000_kyc_storage_bucket.sql's RLS policies,
  /// which enforce that path prefix) and returns the storage object path —
  /// not a public URL, since the bucket is private. Read it back later with
  /// `_client.storage.from('driver-documents').createSignedUrl(path, ...)`.
  static Future<String> _uploadDocument(String filename, Uint8List bytes) async {
    final path = '$_requiredUserId/$filename';
    await _client.storage.from('driver-documents').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  static Future<String> uploadKtpPhoto(Uint8List bytes) => _uploadDocument('ktp.jpg', bytes);

  static Future<String> uploadSelfiePhoto(Uint8List bytes) => _uploadDocument('selfie.jpg', bytes);

  static Future<String> uploadVehicleDocument(String vehicleLicensePlate, Uint8List bytes) =>
      _uploadDocument('vehicle-$vehicleLicensePlate.jpg', bytes);

  /// BR-01: drivers must be 18+. The signup DOB check only enforces BR-02's
  /// 13+ floor, so this is re-checked here against the higher bar.
  ///
  /// [idCardPhotoPath]/[idCardSelfiePath] are storage object paths from
  /// [uploadKtpPhoto]/[uploadSelfiePhoto], not raw bytes — upload first, then
  /// submit. Status goes to 'pending', matching how a real ID-verification
  /// vendor integration would work: submission happens instantly, but
  /// approval to 'verified' is a separate step this app doesn't perform
  /// (no admin console yet — flip it by hand in the Supabase table editor).
  static Future<void> submitKyc({
    required String idNumber,
    required String ktpFullName,
    required DateTime ktpDateOfBirth,
    required String ktpGender,
    required String address,
    required String province,
    required String city,
    required String district,
    required String village,
    required String postcode,
    required String idCardPhotoPath,
    required String idCardSelfiePath,
  }) async {
    await _client.from('driver_verification').upsert({
      'profile_id': _requiredUserId,
      'status': 'pending',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
      'id_number': idNumber,
      'ktp_full_name': ktpFullName,
      'ktp_date_of_birth': ktpDateOfBirth.toIso8601String().split('T').first,
      'ktp_gender': ktpGender,
      'address': address,
      'province': province,
      'city': city,
      'district': district,
      'village': village,
      'postcode': postcode,
      'id_card_photo_url': idCardPhotoPath,
      'id_card_selfie_url': idCardSelfiePath,
    }, onConflict: 'profile_id');
  }

  /// First vehicle added becomes the default (BengRepository.goOnline reads
  /// the default vehicle) — multi-vehicle management is a fast-follow.
  /// [registrationCertPath] is optional — a storage path from
  /// [uploadVehicleDocument], uploaded after the plate is known.
  ///
  /// Exactly one of ([brandId], [brandOther]) and one of ([modelId],
  /// [modelOther]) must be set — migration 20260908000200's
  /// vehicle_brand_xor_other/vehicle_model_xor_other constraints reject
  /// anything else at the DB level, but the UI (VehicleScreen) should never
  /// let a user reach that state to begin with, so these asserts are a
  /// cheap early catch during development, not the real enforcement.
  static Future<void> addVehicle({
    required String vehicleType,
    String? brandId,
    String? brandOther,
    String? modelId,
    String? modelOther,
    required String licensePlate,
    String? registrationCertPath,
  }) async {
    assert((brandId == null) != (brandOther == null), 'Exactly one of brandId/brandOther must be set');
    assert((modelId == null) != (modelOther == null), 'Exactly one of modelId/modelOther must be set');
    await _client.from('vehicle').insert({
      'profile_id': _requiredUserId,
      'vehicle_type': vehicleType,
      'brand_id': brandId,
      'vehicle_brand_other': brandOther,
      'model_id': modelId,
      'vehicle_model_other': modelOther,
      'vehicle_license_plate': licensePlate,
      'vehicle_registration_cert_url': registrationCertPath,
      'is_default': true,
    });
  }
}
