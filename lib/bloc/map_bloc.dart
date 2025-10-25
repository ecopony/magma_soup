// ABOUTME: BLoC for managing map visualization state
// ABOUTME: Handles adding/removing geographic features and map operations

import 'package:bloc/bloc.dart';

import 'map_event.dart';
import 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(const MapState()) {
    on<AddMarkers>(_onAddMarkers);
    on<AddPolylines>(_onAddPolylines);
    on<AddPolygons>(_onAddPolygons);
    on<ClearMap>(_onClearMap);
  }

  void _onAddMarkers(AddMarkers event, Emitter<MapState> emit) {
    emit(state.copyWith(
      markers: [...state.markers, ...event.markers],
    ));
  }

  void _onAddPolylines(AddPolylines event, Emitter<MapState> emit) {
    emit(state.copyWith(
      polylines: [...state.polylines, ...event.polylines],
    ));
  }

  void _onAddPolygons(AddPolygons event, Emitter<MapState> emit) {
    emit(state.copyWith(
      polygons: [...state.polygons, ...event.polygons],
    ));
  }

  void _onClearMap(ClearMap event, Emitter<MapState> emit) {
    emit(const MapState());
  }
}
