// ABOUTME: Client for communicating with the API server.
// ABOUTME: Handles conversation management and SSE streaming for real-time updates.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sse_event.dart';
import '../models/conversation.dart';

/// Client for communicating with the API server.
/// Handles conversation management and SSE streaming.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Creates a new conversation.
  Future<Conversation> createConversation({String? title}) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/conversations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to create conversation: ${response.body}');
    }

    return Conversation.fromJson(jsonDecode(response.body));
  }

  /// Lists recent conversations.
  Future<List<Conversation>> listConversations({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/conversations?limit=$limit&offset=$offset'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to list conversations: ${response.body}');
    }

    final List<dynamic> json = jsonDecode(response.body);
    return json.map((item) => Conversation.fromJson(item)).toList();
  }

  /// Gets a conversation with its full message history.
  Future<ConversationDetail> getConversation(String conversationId) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/conversations/$conversationId'),
    );

    if (response.statusCode == 404) {
      throw ConversationNotFoundException(conversationId);
    } else if (response.statusCode != 200) {
      throw ApiException('Failed to get conversation: ${response.body}');
    }

    return ConversationDetail.fromJson(jsonDecode(response.body));
  }

  /// Sends a message and streams SSE events.
  ///
  /// Returns a stream of SSE events including tool calls, tool results,
  /// and the final response.
  Stream<SSEEvent> sendMessage({
    required String conversationId,
    required String message,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
    );

    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'message': message});

    final streamedResponse = await _httpClient.send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw ApiException('Failed to send message: $body');
    }

    // Parse SSE stream
    String buffer = '';
    String? eventType;
    String? data;

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');

      // Keep the last incomplete line in the buffer
      buffer = lines.last;

      // Process complete lines
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i];

        if (line.startsWith('event: ')) {
          eventType = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          data = line.substring(6).trim();
        } else if (line.isEmpty && eventType != null && data != null) {
          // Complete event received
          try {
            yield SSEEvent.fromRaw(eventType, data);
          } catch (e) {
            // Log error but continue processing stream
            print('Error parsing SSE event: $e');
          }
          eventType = null;
          data = null;
        }
      }
    }

    // Process any remaining buffered event
    if (eventType != null && data != null) {
      try {
        yield SSEEvent.fromRaw(eventType, data);
      } catch (e) {
        print('Error parsing final SSE event: $e');
      }
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

class ConversationNotFoundException implements Exception {
  final String conversationId;
  ConversationNotFoundException(this.conversationId);

  @override
  String toString() => 'Conversation not found: $conversationId';
}
