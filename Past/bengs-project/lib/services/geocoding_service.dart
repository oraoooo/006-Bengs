import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/place.dart';

/// OpenRouteService integration per CLAUDE.md's roadmap ("OpenRouteService
/// or Geoapify free tier for MVP") — this is what finally replaces the
/// manual lat/lng typing that was the honest stopgap everywhere a beng's
/// origin/destination gets set.
///
/// Reads ORS_API_KEY from .env, same pattern as SupabaseService. Every
/// call degrades gracefully (empty results / null) when the key is
/// missing rather than throwing, so the app stays usable — with the old
/// manual-coordinates fallback still available in the UI — before the key
/// is configured.
class GeocodingService {
  GeocodingService._();

  static String? get _apiKey {
    final key = dotenv.env['ORS_API_KEY'];
    return (key == null || key.isEmpty) ? null : key;
  }

  static bool get isConfigured => _apiKey != null;

  /// Place search-as-you-type, biased to Indonesia. Empty below 3
  /// characters — no point spending API calls on "a" or "ja".
  static Future<List<Place>> autocomplete(String query) async {
    final key = _apiKey;
    if (key == null || query.trim().length < 3) return [];

    final uri = Uri.https('api.openrouteservice.org', '/geocode/autocomplete', {
      'api_key': key,
      'text': query.trim(),
      'boundary.country': 'ID',
      'size': '6',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError('Place search failed (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (body['features'] as List?) ?? const [];
    return features.map((f) {
      final feature = f as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List;
      return Place(
        name: properties['label'] as String? ?? properties['name'] as String? ?? query.trim(),
        latitude: (coordinates[1] as num).toDouble(),
        longitude: (coordinates[0] as num).toDouble(),
      );
    }).toList();
  }

  /// Real driving distance/duration between two points, replacing
  /// RouteRepository's haversine-plus-assumed-30km/h estimate for ETAs.
  /// Null (not thrown) on any failure or missing key — callers fall back
  /// to the haversine estimate rather than blocking route computation on
  /// a routing-API outage.
  static Future<RouteEstimate?> route(Place origin, Place destination) async {
    final key = _apiKey;
    if (key == null) return null;

    try {
      final uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car');
      final response = await http
          .post(
            uri,
            headers: {'Authorization': key, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'coordinates': [
                [origin.longitude, origin.latitude],
                [destination.longitude, destination.latitude],
              ],
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final summary = (routes.first as Map<String, dynamic>)['summary'] as Map<String, dynamic>;
      return RouteEstimate(
        distanceKm: (summary['distance'] as num).toDouble() / 1000,
        durationMinutes: (summary['duration'] as num).toDouble() / 60,
      );
    } catch (_) {
      return null;
    }
  }
}

class RouteEstimate {
  const RouteEstimate({required this.distanceKm, required this.durationMinutes});

  final double distanceKm;
  final double durationMinutes;
}
