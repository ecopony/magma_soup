// ABOUTME: Message model representing all types of messages in the conversation.
// ABOUTME: Uses MessageKind enum for exhaustive switching and content polymorphism.

import 'geo_feature.dart';

enum MessageKind {
  user,              // Simple user message for chat display
  assistant,         // Simple assistant message for chat display
  userPrompt,        // Detailed user prompt in trace
  llmResponse,       // Detailed LLM response in trace
  toolCall,          // Tool invocation
  toolResult,        // Tool success result
  toolError,         // Tool error result
  geoFeature,        // Geographic feature data
  error,             // Processing error
}

/// Base class for message content polymorphism
abstract class MessageContent {
  String get displayText;
}

/// Simple text content for user/assistant/error messages
class TextContent implements MessageContent {
  final String text;

  TextContent(this.text);

  @override
  String get displayText => text;
}

/// Detailed user prompt content for trace
class UserPromptContent implements MessageContent {
  final String prompt;

  UserPromptContent(this.prompt);

  @override
  String get displayText => prompt;
}

/// LLM response content with stop reason for trace
class LLMResponseContent implements MessageContent {
  final dynamic content; // Can be String or List<dynamic>
  final String? stopReason;

  LLMResponseContent({
    required this.content,
    this.stopReason,
  });

  /// Extract text content from the response.
  /// Handles both string and array formats.
  String get textContent {
    if (content is String) {
      return content as String;
    } else if (content is List) {
      final textBlocks = (content as List).where((block) =>
        block is Map && block['type'] == 'text'
      );
      return textBlocks
          .map((block) => block['text'] as String)
          .join('\n');
    }
    return '';
  }

  @override
  String get displayText => textContent;
}

/// Tool call content with arguments
class ToolCallContent implements MessageContent {
  final String? toolUseId;
  final String toolName;
  final Map<String, dynamic> arguments;

  ToolCallContent({
    this.toolUseId,
    required this.toolName,
    required this.arguments,
  });

  @override
  String get displayText => 'Tool Call: $toolName';
}

/// Tool result content
class ToolResultContent implements MessageContent {
  final String? toolUseId;
  final String toolName;
  final String result;

  ToolResultContent({
    this.toolUseId,
    required this.toolName,
    required this.result,
  });

  @override
  String get displayText => 'Tool Result: $toolName';
}

/// Tool error content
class ToolErrorContent implements MessageContent {
  final String? toolUseId;
  final String toolName;
  final String error;

  ToolErrorContent({
    this.toolUseId,
    required this.toolName,
    required this.error,
  });

  @override
  String get displayText => 'Tool Error: $toolName - $error';
}

/// Geographic feature content
class GeoFeatureContent implements MessageContent {
  final GeoFeature feature;

  GeoFeatureContent(this.feature);

  @override
  String get displayText => 'Geographic Feature: ${feature.label ?? feature.type}';
}

class Message {
  final String id;
  final MessageKind kind;
  final MessageContent content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.kind,
    required this.content,
    required this.timestamp,
  });

  /// Helper: is this a conversation message (user/assistant only)?
  bool get isConversationMessage =>
      kind == MessageKind.user || kind == MessageKind.assistant;

  /// Helper: is this a trace message (detailed LLM interaction)?
  bool get isTraceMessage =>
      kind == MessageKind.userPrompt ||
      kind == MessageKind.llmResponse ||
      kind == MessageKind.toolCall ||
      kind == MessageKind.toolResult ||
      kind == MessageKind.toolError;

  /// Convenience getter for display text
  String get displayText => content.displayText;
}
