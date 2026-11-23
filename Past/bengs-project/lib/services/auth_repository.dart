import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/age.dart';
import 'supabase_service.dart';

/// BR-02: passengers may sign up from 13, but need parental consent until 18.
/// Nobody under 13 may hold an account at all (there's no driver/passenger
/// distinction yet at sign-up — that's chosen later, per BR-03).
class UnderMinimumAgeException implements Exception {
  const UnderMinimumAgeException();
}

/// Outcome of a successful sign-up, telling the UI whether to route into
/// [AgeGateScreen] next (BR-02/05) before the account is otherwise usable.
class SignUpResult {
  const SignUpResult({required this.userId, required this.needsParentalConsent, required this.hasSession});

  final String userId;
  final bool needsParentalConsent;

  /// False when the Supabase project requires email confirmation before a
  /// session is issued — the caller should prompt the user to check their
  /// inbox rather than navigating straight into the app.
  final bool hasSession;
}

/// Wraps Supabase Auth + the `profiles` row every account needs alongside
/// it. Screens call through here rather than touching `auth.*` or
/// `profiles` directly (mirrors [SupabaseService]/[BengRepository]).
class AuthRepository {
  AuthRepository._();

  static final _client = SupabaseService.client;

  static Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String firstName,
    required String surname,
    required DateTime dateOfBirth,
  }) async {
    final age = calculateAge(dateOfBirth, DateTime.now());
    if (age < 13) throw const UnderMinimumAgeException();
    final needsParentalConsent = age < 18;

    final response = await _client.auth.signUp(email: email, password: password);
    final userId = response.user?.id;
    if (userId == null) {
      throw const AuthException('Sign up did not return a user — please try again');
    }

    // Upsert, not insert: some Supabase projects auto-create a bare stub
    // profiles row (id-only) via a trigger on auth.users the moment
    // signUp() creates the account, before this call ever runs — insert
    // would then fail on profiles_pkey. Upsert fills in the real fields
    // either way.
    await _client.from('profiles').upsert({
      'id': userId,
      'first_name': firstName,
      'surname': surname,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'parental_consent_status': needsParentalConsent ? 'pending' : 'not_required',
    });

    return SignUpResult(
      userId: userId,
      needsParentalConsent: needsParentalConsent,
      hasSession: response.session != null,
    );
  }

  static Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Redirects back into the app via the `app.bengs.auth://login-callback`
  /// scheme registered in Info.plist / AndroidManifest.xml — must match the
  /// redirect URL allow-listed in the Supabase dashboard exactly.
  static Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'app.bengs.auth://login-callback',
    );
  }

  static Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// Starts phone sign-in (BR-08) — Supabase texts a 6-digit code.
  static Future<void> sendPhoneOtp(String phone) {
    return _client.auth.signInWithOtp(phone: phone);
  }

  static Future<void> verifyPhoneOtp({required String phone, required String token}) {
    return _client.auth.verifyOTP(type: OtpType.sms, phone: phone, token: token);
  }

  /// BR-02/05 — records the parent's consent for a passenger aged 13-17.
  /// Status starts 'pending': granting it is a separate confirmation step
  /// (e.g. the parent following an SMS/email link), not implemented here.
  static Future<void> submitParentalConsent({
    required String parentName,
    required String parentPhoneNumber,
    String? parentEmail,
    required String consentMethod,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('submitParentalConsent called with no authenticated user');
    }
    await _client.from('parental_consent').insert({
      'profile_id': userId,
      'parent_name': parentName,
      'parent_phone_number': parentPhoneNumber,
      'parent_email': parentEmail,
      'consent_method': consentMethod,
    });
  }

  /// True once the signed-in user has a `profiles` row. Email/password
  /// signUp always creates one in the same call (see [signUp] above), but
  /// [signInWithGoogle] only authenticates — it never had a "collect
  /// first name / surname / DOB" step of its own, so an OAuth-only account
  /// has none of the fields BR-01/02's age gating and the rest of the app
  /// depend on. [_AuthGate] uses this to route such a user into
  /// CompleteProfileScreen before letting them past the sign-in wall.
  static Future<bool> hasProfile() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;
    final row = await _client.from('profiles').select('id').eq('id', userId).maybeSingle();
    return row != null;
  }

  /// Same BR-01/02 age-gating and `profiles` row shape as [signUp], for an
  /// account that already has a session (Google OAuth) but skipped the
  /// name/DOB collection [signUp] normally does in the same call.
  static Future<SignUpResult> completeOAuthProfile({
    required String firstName,
    required String surname,
    required DateTime dateOfBirth,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw StateError('completeOAuthProfile called with no authenticated user');
    }
    final age = calculateAge(dateOfBirth, DateTime.now());
    if (age < 13) throw const UnderMinimumAgeException();
    final needsParentalConsent = age < 18;

    // Upsert — a retry after an earlier failed attempt on this same screen
    // (or a stub row some other trigger already created) must not crash on
    // profiles_pkey the way a plain insert would.
    await _client.from('profiles').upsert({
      'id': userId,
      'first_name': firstName,
      'surname': surname,
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'parental_consent_status': needsParentalConsent ? 'pending' : 'not_required',
    });

    return SignUpResult(userId: userId, needsParentalConsent: needsParentalConsent, hasSession: true);
  }

  static Future<void> signOut() => _client.auth.signOut();
}
