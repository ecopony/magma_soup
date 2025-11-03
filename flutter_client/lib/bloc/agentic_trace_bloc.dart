// ABOUTME: BLoC managing agentic execution trace state.
// ABOUTME: Tracks tool calls, results, errors, and LLM responses in real-time.

import 'package:bloc/bloc.dart';

import 'agentic_trace_event.dart';
import 'agentic_trace_state.dart';

class AgenticTraceBloc extends Bloc<AgenticTraceEvent, AgenticTraceState> {
  AgenticTraceBloc() : super(const AgenticTraceState()) {
    on<AddToolCall>(_onAddToolCall);
    on<AddToolResult>(_onAddToolResult);
    on<AddToolError>(_onAddToolError);
    on<AddLLMResponse>(_onAddLLMResponse);
    on<ClearTrace>(_onClearTrace);
  }

  void _onAddToolCall(AddToolCall event, Emitter<AgenticTraceState> emit) {
    final newTrace = List<Map<String, dynamic>>.from(state.trace);
    newTrace.add({
      'type': 'tool_call',
      'timestamp': event.timestamp.toIso8601String(),
      'tool_name': event.toolName,
      'arguments': event.arguments,
    });
    emit(state.copyWith(trace: newTrace));
  }

  void _onAddToolResult(AddToolResult event, Emitter<AgenticTraceState> emit) {
    final newTrace = List<Map<String, dynamic>>.from(state.trace);
    newTrace.add({
      'type': 'tool_result',
      'timestamp': event.timestamp.toIso8601String(),
      'tool_name': event.toolName,
      'result': event.result,
    });
    emit(state.copyWith(trace: newTrace));
  }

  void _onAddToolError(AddToolError event, Emitter<AgenticTraceState> emit) {
    final newTrace = List<Map<String, dynamic>>.from(state.trace);
    newTrace.add({
      'type': 'tool_error',
      'timestamp': event.timestamp.toIso8601String(),
      'tool_name': event.toolName,
      'error': event.error,
    });
    emit(state.copyWith(trace: newTrace));
  }

  void _onAddLLMResponse(AddLLMResponse event, Emitter<AgenticTraceState> emit) {
    final newTrace = List<Map<String, dynamic>>.from(state.trace);
    newTrace.add({
      'type': 'llm_response',
      'timestamp': event.timestamp.toIso8601String(),
      'content': event.content,
      'stop_reason': event.stopReason,
    });
    emit(state.copyWith(trace: newTrace));
  }

  void _onClearTrace(ClearTrace event, Emitter<AgenticTraceState> emit) {
    emit(const AgenticTraceState());
  }
}
