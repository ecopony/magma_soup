// ABOUTME: Server-Sent Event models for real-time streaming from API server.
// ABOUTME: Defines event types for tool calls, results, LLM responses, and errors.

import 'dart:convert';
import 'geo_feature.dart';

/// Events streamed from the API server during message processing.
sealed class SSEEvent {
  final DateTime timestamp;

  SSEEvent({DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  factory SSEEvent.fromRaw(String eventType, String data) {
    final Map<String, dynamic> json = jsonDecode(data);

    switch (eventType) {
      case 'user_prompt':
        return UserPromptEvent.fromJson(json);
      case 'tool_call':
        return ToolCallEvent.fromJson(json);
      case 'tool_result':
        return ToolResultEvent.fromJson(json);
      case 'tool_error':
        return ToolErrorEvent.fromJson(json);
      case 'llm_response':
        return LLMResponseEvent.fromJson(json);
      case 'geo_feature':
        return GeoFeatureEvent.fromJson(json);
      case 'remove_geo_feature':
        return RemoveGeoFeatureEvent.fromJson(json);
      case 'done':
        return DoneEvent.fromJson(json);
      case 'error':
        return ErrorEvent.fromJson(json);
      default:
        throw UnknownEventException(eventType);
    }
  }
}

class UserPromptEvent extends SSEEvent {
  final String prompt;

  UserPromptEvent({
    required this.prompt,
    super.timestamp,
  });

  factory UserPromptEvent.fromJson(Map<String, dynamic> json) {
    return UserPromptEvent(
      prompt: json['prompt'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class ToolCallEvent extends SSEEvent {
  final String? toolUseId;
  final String toolName;
  final Map<String, dynamic> arguments;

  ToolCallEvent({
    this.toolUseId,
    required this.toolName,
    required this.arguments,
    super.timestamp,
  });

  factory ToolCallEvent.fromJson(Map<String, dynamic> json) {
    return ToolCallEvent(
      toolUseId: json['tool_use_id'] as String?,
      toolName: json['tool_name'] as String? ?? '',
      arguments: json['arguments'] != null
          ? Map<String, dynamic>.from(json['arguments'] as Map)
          : {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class ToolResultEvent extends SSEEvent {
  final String? toolUseId;
  final String toolName;
  final String result;

  ToolResultEvent({
    this.toolUseId,
    required this.toolName,
    required this.result,
    super.timestamp,
  });

  factory ToolResultEvent.fromJson(Map<String, dynamic> json) {
    return ToolResultEvent(
      toolUseId: json['tool_use_id'] as String?,
      toolName: json['tool_name'] as String? ?? '',
      result: json['result'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class ToolErrorEvent extends SSEEvent {
  final String? toolUseId;
  final String toolName;
  final String error;

  ToolErrorEvent({
    this.toolUseId,
    required this.toolName,
    required this.error,
    super.timestamp,
  });

  factory ToolErrorEvent.fromJson(Map<String, dynamic> json) {
    return ToolErrorEvent(
      toolUseId: json['tool_use_id'] as String?,
      toolName: json['tool_name'] as String? ?? '',
      error: json['error'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class LLMResponseEvent extends SSEEvent {
  final dynamic content; // Can be String or List<dynamic>
  final String? stopReason;

  LLMResponseEvent({
    required this.content,
    this.stopReason,
    super.timestamp,
  });

  factory LLMResponseEvent.fromJson(Map<String, dynamic> json) {
    return LLMResponseEvent(
      content: json['content'], // Keep as-is, can be array or string
      stopReason: json['stop_reason'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

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
}

class GeoFeatureEvent extends SSEEvent {
  final GeoFeature feature;

  GeoFeatureEvent({
    required this.feature,
    super.timestamp,
  });

  factory GeoFeatureEvent.fromJson(Map<String, dynamic> json) {
    // The geo_feature event data IS the feature itself, not wrapped
    return GeoFeatureEvent(
      feature: GeoFeature.fromJson(json),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class RemoveGeoFeatureEvent extends SSEEvent {
  final String featureId;

  RemoveGeoFeatureEvent({
    required this.featureId,
    super.timestamp,
  });

  factory RemoveGeoFeatureEvent.fromJson(Map<String, dynamic> json) {
    return RemoveGeoFeatureEvent(
      featureId: json['feature_id'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class DoneEvent extends SSEEvent {
  final String finalResponse;

  DoneEvent({
    required this.finalResponse,
    super.timestamp,
  });

  factory DoneEvent.fromJson(Map<String, dynamic> json) {
    return DoneEvent(
      finalResponse: json['final_response'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class ErrorEvent extends SSEEvent {
  final String message;
  final String? code;

  ErrorEvent({
    required this.message,
    this.code,
    super.timestamp,
  });

  factory ErrorEvent.fromJson(Map<String, dynamic> json) {
    return ErrorEvent(
      message: json['message'] as String? ?? 'Unknown error',
      code: json['code'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

class UnknownEventException implements Exception {
  final String eventType;
  UnknownEventException(this.eventType);

  @override
  String toString() => 'Unknown SSE event type: $eventType';
}
