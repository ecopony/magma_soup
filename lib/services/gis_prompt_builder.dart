class GisPromptBuilder {
  static const String _systemContext = '''
You are a GIS (Geographic Information Systems) processing assistant. You help users with geospatial data analysis, manipulation, and transformation tasks.
''';

  static String buildPrompt(String userCommand) {
    return '''$_systemContext

User request: $userCommand

Attempt to complete the user's request. If you lack the tools to do so, let the user know.''';
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
