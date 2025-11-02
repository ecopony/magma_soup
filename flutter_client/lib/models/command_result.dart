import 'geo_feature.dart';

class CommandResult {
  final String id;
  final String command;
  final String output;
  final DateTime timestamp;
  final List<GeoFeature> geoFeatures;
  final List<Map<String, dynamic>> llmHistory;

  CommandResult({
    required this.id,
    required this.command,
    required this.output,
    required this.timestamp,
    this.geoFeatures = const [],
    this.llmHistory = const [],
  });
}
