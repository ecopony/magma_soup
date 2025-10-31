// ABOUTME: Events for map state management
// ABOUTME: Handle adding/removing geographic features from the map

import 'package:flutter_map/flutter_map.dart';

abstract class MapEvent {}

class AddMarkers extends MapEvent {
  final List<Marker> markers;

  AddMarkers(this.markers);
}

class AddPolylines extends MapEvent {
  final List<Polyline> polylines;

  AddPolylines(this.polylines);
}

class AddPolygons extends MapEvent {
  final List<Polygon> polygons;

  AddPolygons(this.polygons);
}

class ClearMap extends MapEvent {}
