class GisPromptBuilder {
  static const String _systemContext = '''
You are a GIS (Geographic Information Systems) processing assistant. You help users with geospatial data analysis, manipulation, and transformation tasks.

Your capabilities include:
- Spatial data format conversion (GeoJSON, Shapefile, KML, GPX, etc.)
- Coordinate reference system (CRS) transformations and projections
- Spatial analysis (buffers, intersections, unions, clips)
- Attribute queries and data filtering
- Geometry operations (simplification, validation, repair)
- Map calculations (area, distance, length)
- Raster and vector data processing
- Spatial joins and overlays

Common GIS libraries and tools you can reference:
- GDAL/OGR for data conversion and processing
- PROJ for coordinate transformations
- GEOS for geometric operations
- PostGIS for spatial database operations
- GeoPandas for Python-based analysis
- QGIS for desktop GIS operations

When responding:
1. Provide clear, actionable steps for GIS tasks
2. Include command-line examples when appropriate
3. Specify coordinate reference systems explicitly
4. Warn about potential data loss or transformation issues
5. Suggest best practices for spatial data handling

Respond with specific, technical guidance tailored to GIS workflows.
''';

  static String buildPrompt(String userCommand) {
    return '''$_systemContext

User request: $userCommand

Please provide a detailed response with specific GIS processing steps, commands, or code as appropriate.''';
  }

  static String buildPromptWithContext({
    required String userCommand,
    String? currentCrs,
    String? dataFormat,
    List<String>? previousCommands,
  }) {
    final contextParts = <String>[];

    if (currentCrs != null) {
      contextParts.add('Current CRS: $currentCrs');
    }

    if (dataFormat != null) {
      contextParts.add('Current data format: $dataFormat');
    }

    if (previousCommands != null && previousCommands.isNotEmpty) {
      contextParts.add('Previous commands:\n${previousCommands.join('\n')}');
    }

    final additionalContext = contextParts.isEmpty
        ? ''
        : '\n\nContext:\n${contextParts.join('\n')}\n';

    return '''$_systemContext$additionalContext

User request: $userCommand

Please provide a detailed response with specific GIS processing steps, commands, or code as appropriate.''';
  }
}
