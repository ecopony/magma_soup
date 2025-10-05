import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class McpService {
  static const String _baseUrl = 'http://localhost:3000';
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTime,
    ),
  );

  /// List available tools from the MCP server
  Future<List<Map<String, dynamic>>> listTools() async {
    _logger.i('Fetching tools from $_baseUrl/tools/list');
    final response = await http.post(
      Uri.parse('$_baseUrl/tools/list'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tools = List<Map<String, dynamic>>.from(data['tools'] ?? []);
      _logger.d('Retrieved ${tools.length} tools: ${tools.map((t) => t['name']).join(', ')}');
      return tools;
    }
    throw Exception('Failed to list tools: ${response.body}');
  }

  /// Call a specific tool on the MCP server
  Future<String> callTool({
    required String toolName,
    required Map<String, dynamic> arguments,
  }) async {
    _logger.i('Calling tool: $toolName');
    _logger.d('Arguments: $arguments');
    final response = await http.post(
      Uri.parse('$_baseUrl/tools/call'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': toolName,
        'arguments': arguments,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      if (content.isNotEmpty && content[0]['type'] == 'text') {
        final result = content[0]['text'] as String;
        _logger.i('Tool result: $result');
        return result;
      }
      throw Exception('Unexpected tool response format');
    }
    throw Exception('Failed to call tool: ${response.statusCode} - ${response.body}');
  }

  /// Get tools in Anthropic API format
  Future<List<Map<String, dynamic>>> getToolsForAnthropic() async {
    final tools = await listTools();
    return tools
        .map((tool) => {
              'name': tool['name'],
              'description': tool['description'],
              'input_schema': tool['inputSchema'],
            })
        .toList();
  }
}
