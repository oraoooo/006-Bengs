/// Resolves a vehicle row's brand/model to a display string.
///
/// [vehicle] is expected to come from a query that joined the lookup tables
/// (`brand:brand_id(name)`, `model:model_id(name)`) alongside the raw
/// `vehicle_brand_other`/`vehicle_model_other` columns. Per VEH-01/migration
/// 20260908000200, exactly one of (brand_id, vehicle_brand_other) and one of
/// (model_id, vehicle_model_other) is ever set — the lookup join is null
/// whenever the driver picked "Other, not listed," so callers must never
/// assume the lookup path always has data.
String? vehicleBrandModelLabel(Map<String, dynamic>? vehicle) {
  if (vehicle == null) return null;

  final brandRow = vehicle['brand'] as Map<String, dynamic>?;
  final modelRow = vehicle['model'] as Map<String, dynamic>?;
  final brand = (brandRow?['name'] as String?) ?? (vehicle['vehicle_brand_other'] as String?);
  final model = (modelRow?['name'] as String?) ?? (vehicle['vehicle_model_other'] as String?);

  final parts = [brand, model].where((s) => s != null && s.isNotEmpty).toList();
  return parts.isEmpty ? null : parts.join(' ');
}
