// ABOUTME: Basic map widget using flutter_map
// ABOUTME: Displays an OpenStreetMap tile layer and geocoded location markers

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../bloc/map_bloc.dart';
import '../../bloc/map_state.dart';

class MapWidget extends StatelessWidget {
  const MapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        return SizedBox(
          height: 300,
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(37.7749, -122.4194), // San Francisco
              initialZoom: 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.magma_soup',
              ),
              if (state.polygons.isNotEmpty)
                PolygonLayer(polygons: state.polygons),
              if (state.polylines.isNotEmpty)
                PolylineLayer(polylines: state.polylines),
              if (state.markers.isNotEmpty) MarkerLayer(markers: state.markers),
            ],
          ),
        );
      },
    );
  }
}
