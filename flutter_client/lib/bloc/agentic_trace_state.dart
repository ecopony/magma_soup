// ABOUTME: State for AgenticTraceBloc containing LLM execution trace.
// ABOUTME: Stores ordered list of tool calls, results, and LLM responses.

class AgenticTraceState {
  final List<Map<String, dynamic>> trace;

  const AgenticTraceState({
    this.trace = const [],
  });

  AgenticTraceState copyWith({
    List<Map<String, dynamic>>? trace,
  }) {
    return AgenticTraceState(
      trace: trace ?? this.trace,
    );
  }
}
