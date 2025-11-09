// ABOUTME: Decoder for converting SSEEvents to Message objects.
// ABOUTME: Provides the translation boundary between streaming events and unified message model.

import '../models/message.dart';
import '../models/sse_event.dart';

class MessageDecoder {
  /// Decodes an SSEEvent into a Message.
  /// Returns null for events that don't become messages (like DoneEvent).
  static Message? decode(SSEEvent event) {
    return switch (event) {
      UserPromptEvent() => Message(
        id: '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.userPrompt,
        content: UserPromptContent(event.prompt),
        timestamp: event.timestamp,
      ),
      ToolCallEvent() => Message(
        id: event.toolUseId ?? '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.toolCall,
        content: ToolCallContent(
          toolUseId: event.toolUseId,
          toolName: event.toolName,
          arguments: event.arguments,
        ),
        timestamp: event.timestamp,
      ),
      ToolResultEvent() => Message(
        id: event.toolUseId ?? '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.toolResult,
        content: ToolResultContent(
          toolUseId: event.toolUseId,
          toolName: event.toolName,
          result: event.result,
        ),
        timestamp: event.timestamp,
      ),
      ToolErrorEvent() => Message(
        id: event.toolUseId ?? '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.toolError,
        content: ToolErrorContent(
          toolUseId: event.toolUseId,
          toolName: event.toolName,
          error: event.error,
        ),
        timestamp: event.timestamp,
      ),
      LLMResponseEvent() => Message(
        id: '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.llmResponse,
        content: LLMResponseContent(
          content: event.content,
          stopReason: event.stopReason,
        ),
        timestamp: event.timestamp,
      ),
      GeoFeatureEvent() => Message(
        id: '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.geoFeature,
        content: GeoFeatureContent(event.feature),
        timestamp: event.timestamp,
      ),
      RemoveGeoFeatureEvent() => Message(
        id: '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.removeGeoFeature,
        content: RemoveGeoFeatureContent(event.featureId),
        timestamp: event.timestamp,
      ),
      ErrorEvent() => Message(
        id: '${event.timestamp.millisecondsSinceEpoch}',
        kind: MessageKind.error,
        content: TextContent(event.message),
        timestamp: event.timestamp,
      ),
      DoneEvent() => null, // DoneEvent doesn't become a message
    };
  }
}
