// ABOUTME: Tests for MapBloc location initialization and auto-adjust
// ABOUTME: Verifies that user location is fetched and map is centered correctly

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:magma_soup/bloc/map_bloc.dart';
import 'package:magma_soup/bloc/map_event.dart';
import 'package:magma_soup/bloc/map_state.dart';
import 'package:magma_soup/services/api_client.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('MapBloc', () {
    group('Auto-frame functionality', () {
      blocTest<MapBloc, MapState>(
        'initial state has auto-frame enabled',
        build: () {
          return MapBloc();
        },
        verify: (bloc) {
          expect(bloc.state.autoFrameEnabled, true);
          expect(bloc.state.conversationBounds, null);
        },
      );

      blocTest<MapBloc, MapState>(
        'DisableAutoFrame disables auto-frame',
        build: () {
          return MapBloc();
        },
        act: (bloc) => bloc.add(DisableAutoFrame()),
        expect: () => [
          isA<MapState>()
              .having((s) => s.autoFrameEnabled, 'autoFrameEnabled', false),
        ],
      );

      blocTest<MapBloc, MapState>(
        'EnableAutoFrame enables auto-frame',
        build: () {
          return MapBloc();
        },
        seed: () => MapState(autoFrameEnabled: false),
        act: (bloc) => bloc.add(EnableAutoFrame()),
        expect: () => [
          isA<MapState>()
              .having((s) => s.autoFrameEnabled, 'autoFrameEnabled', true),
        ],
      );

      blocTest<MapBloc, MapState>(
        'AddMarkers sets conversation bounds when auto-frame is enabled',
        build: () {
          return MapBloc();
        },
        act: (bloc) => bloc.add(AddMarkers([
          Marker(
            point: const LatLng(40.7128, -74.0060),
            child: Container(),
          ),
        ])),
        expect: () => [
          isA<MapState>()
              .having((s) => s.markers.length, 'markers length', 1)
              .having(
                  (s) => s.conversationBounds, 'conversationBounds', isNotNull),
        ],
      );

      blocTest<MapBloc, MapState>(
        'AddMarkers does not update bounds when auto-frame is disabled',
        build: () {
          return MapBloc();
        },
        seed: () => MapState(autoFrameEnabled: false),
        act: (bloc) => bloc.add(AddMarkers([
          Marker(
            point: const LatLng(40.7128, -74.0060),
            child: Container(),
          ),
        ])),
        expect: () => [
          isA<MapState>()
              .having((s) => s.markers.length, 'markers length', 1)
              .having((s) => s.conversationBounds, 'conversationBounds', null),
        ],
      );

      blocTest<MapBloc, MapState>(
        'AddMarkers expands conversation bounds for multiple markers',
        build: () {
          return MapBloc();
        },
        seed: () => MapState(
          autoFrameEnabled: true,
          markers: [
            Marker(
              point: const LatLng(40.5, -73.5),
              child: Container(),
            ),
          ],
          conversationBounds: LatLngBounds(
            const LatLng(40.0, -74.0),
            const LatLng(41.0, -73.0),
          ),
        ),
        act: (bloc) => bloc.add(AddMarkers([
          Marker(
            point: const LatLng(42.0, -75.0),
            child: Container(),
          ),
        ])),
        verify: (bloc) {
          expect(bloc.state.conversationBounds, isNotNull);
          // Should include both the existing marker (40.5) and new marker (42.0)
          expect(bloc.state.conversationBounds!.southWest.latitude,
              lessThanOrEqualTo(40.5));
          expect(bloc.state.conversationBounds!.northEast.latitude,
              greaterThanOrEqualTo(42.0));
        },
      );

      blocTest<MapBloc, MapState>(
        'conversation bounds calculated correctly for first marker with auto-frame',
        build: () {
          return MapBloc();
        },
        act: (bloc) => bloc.add(AddMarkers([
          Marker(
            point: const LatLng(40.7128, -74.0060),
            child: Container(),
          ),
        ])),
        verify: (bloc) {
          const markerPoint = LatLng(40.7128, -74.0060);

          // Bounds should be calculated and contain the marker
          expect(bloc.state.conversationBounds, isNotNull);
          expect(bloc.state.conversationBounds!.contains(markerPoint), true);

          // For a single point, bounds will have equal corners (the point itself)
          final bounds = bloc.state.conversationBounds!;
          expect(bounds.southWest.latitude,
              lessThanOrEqualTo(markerPoint.latitude));
          expect(bounds.northEast.latitude,
              greaterThanOrEqualTo(markerPoint.latitude));
          expect(bounds.southWest.longitude,
              lessThanOrEqualTo(markerPoint.longitude));
          expect(bounds.northEast.longitude,
              greaterThanOrEqualTo(markerPoint.longitude));
        },
      );

      blocTest<MapBloc, MapState>(
        'camera does not adjust when auto-frame disabled',
        build: () {
          return MapBloc();
        },
        seed: () => MapState(autoFrameEnabled: false),
        act: (bloc) {
          bloc.add(AddMarkers([
            Marker(
              point: const LatLng(40.7128, -74.0060),
              child: Container(),
            ),
          ]));
          return Future.value();
        },
        verify: (bloc) {
          // Camera should remain at initial position
          expect(bloc.state.center.latitude, 37.7749);
          expect(bloc.state.center.longitude, -122.4194);
        },
      );

      blocTest<MapBloc, MapState>(
        'AddPolylines adjusts camera to include line',
        build: () {
          return MapBloc();
        },
        act: (bloc) => bloc.add(AddPolylines([
          Polyline(
            points: [
              const LatLng(40.7128, -74.0060),
              const LatLng(40.7589, -73.9851),
            ],
            color: Colors.blue,
          ),
        ])),
        verify: (bloc) {
          expect(bloc.state.conversationBounds, isNotNull);
          // Camera should encompass both points
          final bounds = bloc.state.conversationBounds!;
          expect(bounds.southWest.latitude, lessThanOrEqualTo(40.7128));
          expect(bounds.northEast.latitude, greaterThanOrEqualTo(40.7589));
          expect(bounds.southWest.longitude, lessThanOrEqualTo(-74.0060));
          expect(bounds.northEast.longitude, greaterThanOrEqualTo(-73.9851));
        },
      );

      blocTest<MapBloc, MapState>(
        'AddPolygons adjusts camera to include polygon',
        build: () {
          return MapBloc();
        },
        act: (bloc) => bloc.add(AddPolygons([
          Polygon(
            points: [
              const LatLng(40.7128, -74.0060),
              const LatLng(40.7589, -73.9851),
              const LatLng(40.7489, -73.9680),
            ],
            color: Colors.green.withOpacity(0.3),
          ),
        ])),
        verify: (bloc) {
          expect(bloc.state.conversationBounds, isNotNull);
          // Camera should encompass all polygon points
          final bounds = bloc.state.conversationBounds!;
          expect(bounds.southWest.latitude, lessThanOrEqualTo(40.7128));
          expect(bounds.northEast.latitude, greaterThanOrEqualTo(40.7589));
        },
      );

      blocTest<MapBloc, MapState>(
        'camera readjusts when new features extend significantly beyond current view',
        build: () {
          return MapBloc();
        },
        seed: () => MapState(
          autoFrameEnabled: true,
          markers: [
            Marker(
              point: const LatLng(40.7128, -74.0060),
              child: Container(),
            ),
          ],
          conversationBounds: LatLngBounds(
            const LatLng(40.5, -74.2),
            const LatLng(40.9, -73.8),
          ),
        ),
        act: (bloc) => bloc.add(AddMarkers([
          // Add marker far outside current bounds (San Francisco vs New York)
          Marker(
            point: const LatLng(37.7749, -122.4194),
            child: Container(),
          ),
        ])),
        verify: (bloc) {
          // Bounds should now encompass both New York and San Francisco
          final bounds = bloc.state.conversationBounds!;
          expect(bounds.southWest.latitude, lessThanOrEqualTo(37.7749));
          expect(bounds.northEast.latitude, greaterThanOrEqualTo(40.7128));
          expect(bounds.southWest.longitude, lessThanOrEqualTo(-122.4194));
          expect(bounds.northEast.longitude, greaterThanOrEqualTo(-74.0060));
        },
      );

      blocTest<MapBloc, MapState>(
        'ZoomIn disables auto-frame',
        build: () {
          return MapBloc();
        },
        seed: () => MapState(autoFrameEnabled: true),
        act: (bloc) => bloc.add(ZoomIn()),
        verify: (bloc) {
          expect(bloc.state.autoFrameEnabled, false);
          expect(bloc.state.zoom, 6.0); // Initial 5.0 + 1.0
        },
      );

      blocTest<MapBloc, MapState>(
        'ZoomOut disables auto-frame',
        build: () {
          return MapBloc();
        },
        seed: () => MapState(autoFrameEnabled: true),
        act: (bloc) => bloc.add(ZoomOut()),
        verify: (bloc) {
          expect(bloc.state.autoFrameEnabled, false);
          expect(bloc.state.zoom, 4.0); // Initial 5.0 - 1.0
        },
      );

      blocTest<MapBloc, MapState>(
        'camera adjusts when second distant marker is added (Portland to Denver)',
        build: () {
          return MapBloc();
        },
        act: (bloc) async {
          // Add Portland first (like "distance from Portland, OR")
          bloc.add(AddMarkers([
            Marker(
              point: const LatLng(45.5152, -122.6784), // Portland
              child: Container(),
            ),
          ]));
          await Future.delayed(Duration.zero); // Let first marker process

          // Add Denver second (like "to Denver, CO")
          bloc.add(AddMarkers([
            Marker(
              point: const LatLng(39.7392, -104.9903), // Denver
              child: Container(),
            ),
          ]));
        },
        verify: (bloc) {
          // Bounds should encompass both Portland and Denver
          final bounds = bloc.state.conversationBounds!;
          expect(bounds.southWest.latitude, lessThanOrEqualTo(39.7392)); // Denver lat
          expect(bounds.northEast.latitude, greaterThanOrEqualTo(45.5152)); // Portland lat
          expect(bounds.southWest.longitude, lessThanOrEqualTo(-122.6784)); // Portland lng
          expect(bounds.northEast.longitude, greaterThanOrEqualTo(-104.9903)); // Denver lng
        },
      );
    });
  });
}
