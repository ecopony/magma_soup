// ABOUTME: Extracts geographic features from MCP tool results
// ABOUTME: Converts geocoding and other geo tool outputs into map markers

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeoFeatureExtractor {
  /// Extract map markers from a tool result
  List<Marker> extractMarkers({
    required String toolName,
    required String result,
    required Map<String, dynamic> arguments,
  }) {
    switch (toolName) {
      case 'geocode_address':
        return _extractGeocodeMarker(result, arguments);
      default:
        return [];
    }
  }

  List<Marker> _extractGeocodeMarker(
    String result,
    Map<String, dynamic> arguments,
  ) {
    try {
      final geocodeResult = jsonDecode(result);
      final lat = double.parse(geocodeResult['lat'].toString());
      final lon = double.parse(geocodeResult['lon'].toString());
      final name = geocodeResult['display_name']?.toString() ??
          arguments['address']?.toString() ??
          'Unknown';

      return [
        Marker(
          point: LatLng(lat, lon),
          width: 200,
          height: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_pin,
                color: Color(0xFFdc322f), // Solarized red
                size: 40,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFfdf6e3), // Solarized base3
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF586e75), // Solarized base01
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ];
    } catch (e) {
      return [];
    }
  }
}
