import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

class AnthropicService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  final String _apiKey;
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

  AnthropicService({String? apiKey})
      : _apiKey = apiKey ?? dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  Future<Map<String, dynamic>> sendMessage({
    String? prompt,
    String model = 'claude-sonnet-4-5-20250929',
    int maxTokens = 4096,
    List<Map<String, dynamic>>? tools,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Anthropic API key not configured');
    }

    if (conversationHistory == null && (prompt == null || prompt.isEmpty)) {
      throw Exception('Either prompt or conversationHistory must be provided');
    }

    final messages = conversationHistory ??
        [
          {
            'role': 'user',
            'content': prompt!,
          }
        ];

    final requestBody = {
      'model': model,
      'max_tokens': maxTokens,
      'messages': messages,
    };

    if (tools != null && tools.isNotEmpty) {
      requestBody['tools'] = tools;
      _logger.i('Calling Claude API with ${tools.length} tools available');
    } else {
      _logger.i('Calling Claude API without tools');
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      final stopReason = result['stop_reason'];
      _logger.i('Claude response received. Stop reason: $stopReason');
      return result;
    } else {
      throw Exception(
          'API request failed: ${response.statusCode} - ${response.body}');
    }
  }

  String extractTextResponse(Map<String, dynamic> response) {
    final content = response['content'] as List?;
    if (content == null || content.isEmpty) {
      return '';
    }
    final textParts = content.where((c) => c is Map && c['type'] == 'text');
    return textParts.map((c) => c['text'] ?? '').join('\n');
  }

  List<Map<String, dynamic>> extractToolUses(Map<String, dynamic> response) {
    final content = response['content'] as List?;
    if (content == null || content.isEmpty) {
      return [];
    }
    return content
        .where((c) => c is Map && c['type'] == 'tool_use')
        .map((c) => c as Map<String, dynamic>)
        .toList();
  }
}
