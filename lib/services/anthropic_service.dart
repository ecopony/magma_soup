import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AnthropicService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  final String _apiKey;

  AnthropicService({String? apiKey})
      : _apiKey = apiKey ?? dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  Future<String> sendMessage({
    required String prompt,
    String model = 'claude-sonnet-4-5-20250929',
    int maxTokens = 4096,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Anthropic API key not configured');
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      if (content.isNotEmpty && content[0]['type'] == 'text') {
        return content[0]['text'] as String;
      }
      throw Exception('Unexpected response format');
    } else {
      throw Exception(
          'API request failed: ${response.statusCode} - ${response.body}');
    }
  }
}
