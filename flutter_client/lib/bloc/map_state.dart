// ABOUTME: State for the map visualization
// ABOUTME: Contains all geographic features (markers, polylines, polygons)

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapState {
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<Polygon> polygons;
  final MapController mapController;
  final double zoom;
  final LatLng center;

  MapState({
    this.markers = const [],
    this.polylines = const [],
    this.polygons = const [],
    MapController? mapController,
    this.zoom = 5.0,
    this.center = const LatLng(37.7749, -122.4194), // San Francisco
  }) : mapController = mapController ?? MapController();

  MapState copyWith({
    List<Marker>? markers,
    List<Polyline>? polylines,
    List<Polygon>? polygons,
    MapController? mapController,
    double? zoom,
    LatLng? center,
  }) {
    return MapState(
      markers: markers ?? this.markers,
      polylines: polylines ?? this.polylines,
      polygons: polygons ?? this.polygons,
      mapController: mapController ?? this.mapController,
      zoom: zoom ?? this.zoom,
      center: center ?? this.center,
    );
  }
}
