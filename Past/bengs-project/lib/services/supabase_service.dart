import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase init/access so the rest of the app never
/// touches `Supabase.instance` directly (BENGS_path_to_production: keep
/// backend wiring in one place, screens stay UI-only).
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Call once from `main()` before `runApp`.
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    await Supabase.initialize(
      url: dotenv.get('SUPABASE_URL'),
      publishableKey: dotenv.get('SUPABASE_ANON_KEY'),
    );
  }

  static User? get currentUser => client.auth.currentUser;
}
