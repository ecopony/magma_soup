// ABOUTME: State for the map visualization
// ABOUTME: Contains all geographic features (markers, polylines, polygons)

import 'package:flutter_map/flutter_map.dart';

class MapState {
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<Polygon> polygons;

  const MapState({
    this.markers = const [],
    this.polylines = const [],
    this.polygons = const [],
  });

  MapState copyWith({
    List<Marker>? markers,
    List<Polyline>? polylines,
    List<Polygon>? polygons,
  }) {
    return MapState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      polygons: polygons ?? this.polygons,
    );
  }
}
