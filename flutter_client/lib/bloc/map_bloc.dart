// ABOUTME: BLoC for managing map visualization state
// ABOUTME: Handles adding/removing geographic features and map operations

import 'package:bloc/bloc.dart';

import 'map_event.dart';
import 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc() : super(MapState()) {
    on<AddMarkers>(_onAddMarkers);
    on<AddPolylines>(_onAddPolylines);
    on<AddPolygons>(_onAddPolygons);
    on<ClearMap>(_onClearMap);
    on<ZoomIn>(_onZoomIn);
    on<ZoomOut>(_onZoomOut);
    on<SetZoom>(_onSetZoom);
    on<UpdateMapPosition>(_onUpdateMapPosition);
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
    emit(MapState());
  }

  void _onZoomIn(ZoomIn event, Emitter<MapState> emit) {
    final newZoom = state.zoom + 1.0;
    state.mapController.move(state.center, newZoom);
    emit(state.copyWith(zoom: newZoom));
  }

  void _onZoomOut(ZoomOut event, Emitter<MapState> emit) {
    final newZoom = state.zoom - 1.0;
    state.mapController.move(state.center, newZoom);
    emit(state.copyWith(zoom: newZoom));
  }

  void _onSetZoom(SetZoom event, Emitter<MapState> emit) {
    state.mapController.move(state.center, event.zoom);
    emit(state.copyWith(zoom: event.zoom));
  }

  void _onUpdateMapPosition(UpdateMapPosition event, Emitter<MapState> emit) {
    emit(state.copyWith(
      center: event.center,
      zoom: event.zoom,
    ));
  }
}
