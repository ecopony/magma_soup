// ABOUTME: Geographic feature model for markers and spatial data.
// ABOUTME: Extracted from tool results and displayed on the map.

/// Geographic feature extracted from tool results.
class GeoFeature {
  final String id;
  final String type;
  final double lat;
  final double lon;
  final String? label;

  GeoFeature({
    required this.id,
    required this.type,
    required this.lat,
    required this.lon,
    this.label,
  });

  factory GeoFeature.fromJson(Map<String, dynamic> json) {
    return GeoFeature(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'marker',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'lat': lat,
      'lon': lon,
      'label': label,
    };
  }
}
