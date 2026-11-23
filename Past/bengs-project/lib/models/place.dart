/// A named point on the map — what GeocodingService's autocomplete search
/// resolves free-text into, replacing the manual lat/lng entry that used
/// to be the only way to set a beng's origin/destination.
class Place {
  const Place({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;
}
