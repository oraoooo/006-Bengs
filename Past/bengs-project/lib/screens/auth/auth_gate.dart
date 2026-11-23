import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/main_scaffold.dart';
import 'complete_profile_screen.dart';
import 'welcome_screen.dart';

/// Listens to Supabase's auth state and shows [WelcomeScreen] (and the
/// login/sign-up/OTP flow reachable from it) when signed out, or
/// [MainScaffold] once a session exists — this is what makes signing in
/// from any of those screens land the user in the app with no manual
/// navigation call needed.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStateStream = SupabaseService.client.auth.onAuthStateChange;
  late Future<bool> _hasProfileFuture = AuthRepository.hasProfile();
  late final Future<bool> _driverVerifiedFuture = _isDriverVerified();

  /// Reads driverVerification.status for the signed-in user (BR-03/BR-04) so
  /// MainScaffold gets a real `isDriverVerified` instead of a hardcoded value.
  Future<bool> _isDriverVerified() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;
    final row = await SupabaseService.client
        .from('driver_verification')
        .select('status')
        .eq('profile_id', userId)
        .maybeSingle();
    return row?['status'] == 'verified';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStateStream,
      initialData: AuthState(AuthChangeEvent.initialSession, SupabaseService.client.auth.currentSession),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;
        if (session == null) {
          return const WelcomeScreen();
        }
        // Google OAuth (see AuthRepository.signInWithGoogle) only
        // authenticates — unlike email signUp, it never collects
        // first name/surname/DOB into a `profiles` row in the same step,
        // so getMyProfile() and everything downstream of it 0-row-fails
        // until that's filled in here.
        return FutureBuilder<bool>(
          future: _hasProfileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (profileSnapshot.data != true) {
              return CompleteProfileScreen(
                onComplete: () => setState(() => _hasProfileFuture = AuthRepository.hasProfile()),
              );
            }
            return FutureBuilder<bool>(
              future: _driverVerifiedFuture,
              builder: (context, driverSnapshot) {
                if (driverSnapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return MainScaffold(
                  key: ValueKey(session.user.id),
                  isDriverVerified: driverSnapshot.data ?? false,
                );
              },
            );
          },
        );
      },
    );
  }
}
