// ABOUTME: Events for AgenticTraceBloc to track LLM tool execution.
// ABOUTME: Represents tool calls, results, errors, and LLM responses during agentic loop.

abstract class AgenticTraceEvent {}

class AddToolCall extends AgenticTraceEvent {
  final String toolName;
  final Map<String, dynamic> arguments;
  final DateTime timestamp;

  AddToolCall({
    required this.toolName,
    required this.arguments,
    required this.timestamp,
  });
}

class AddToolResult extends AgenticTraceEvent {
  final String toolName;
  final dynamic result;
  final DateTime timestamp;

  AddToolResult({
    required this.toolName,
    required this.result,
    required this.timestamp,
  });
}

class AddToolError extends AgenticTraceEvent {
  final String toolName;
  final String error;
  final DateTime timestamp;

  AddToolError({
    required this.toolName,
    required this.error,
    required this.timestamp,
  });
}

class AddLLMResponse extends AgenticTraceEvent {
  final dynamic content;
  final String? stopReason;
  final DateTime timestamp;

  AddLLMResponse({
    required this.content,
    this.stopReason,
    required this.timestamp,
  });
}

class ClearTrace extends AgenticTraceEvent {}
