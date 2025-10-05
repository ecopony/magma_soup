import 'package:bloc/bloc.dart';
import '../models/message.dart';
import '../models/command_result.dart';
import '../services/anthropic_service.dart';
import '../services/mcp_service.dart';
import '../services/gis_prompt_builder.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AnthropicService _anthropicService;
  final McpService _mcpService;

  ChatBloc({
    AnthropicService? anthropicService,
    McpService? mcpService,
  })  : _anthropicService = anthropicService ?? AnthropicService(),
        _mcpService = mcpService ?? McpService(),
        super(ChatState()) {
    on<SendCommand>(_onSendCommand);
  }

  Future<void> _onSendCommand(SendCommand event, Emitter<ChatState> emit) async {
    // Add user message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: event.command,
      timestamp: DateTime.now(),
      type: MessageType.user,
    );

    emit(state.copyWith(
      messages: [...state.messages, userMessage],
      status: ChatStatus.loading,
    ));

    try {
      // Build prompt with GIS context
      final prompt = GisPromptBuilder.buildPrompt(event.command);

      // Get MCP tools
      final tools = await _mcpService.getToolsForAnthropic();

      // Call Anthropic with MCP tools
      var response = await _anthropicService.sendMessage(
        prompt: prompt,
        tools: tools,
      );

      // Handle tool use loop with safety limit
      final conversationHistory = <Map<String, dynamic>>[
        {'role': 'user', 'content': prompt}
      ];

      int toolCallCount = 0;
      const maxToolCalls = 10;

      while (response['stop_reason'] == 'tool_use' &&
          toolCallCount < maxToolCalls) {
        toolCallCount++;

        conversationHistory.add({
          'role': 'assistant',
          'content': response['content'],
        });

        // Execute all tool uses
        final toolUses = _anthropicService.extractToolUses(response);
        final toolResults = <Map<String, dynamic>>[];

        for (final toolUse in toolUses) {
          final toolName = toolUse['name'] as String;
          final toolInput = toolUse['input'] as Map<String, dynamic>;
          final toolUseId = toolUse['id'] as String;

          try {
            final result = await _mcpService.callTool(
              toolName: toolName,
              arguments: toolInput,
            );

            toolResults.add({
              'type': 'tool_result',
              'tool_use_id': toolUseId,
              'content': result,
            });
          } catch (e) {
            toolResults.add({
              'type': 'tool_result',
              'tool_use_id': toolUseId,
              'content': 'Error: ${e.toString()}',
              'is_error': true,
            });
          }
        }

        conversationHistory.add({
          'role': 'user',
          'content': toolResults,
        });

        // Continue conversation with tool results
        response = await _anthropicService.sendMessage(
          tools: tools,
          conversationHistory: conversationHistory,
        );
      }

      // Check if we hit the tool call limit
      if (toolCallCount >= maxToolCalls) {
        throw Exception(
            'Maximum tool call limit ($maxToolCalls) reached. Please try rephrasing your request.');
      }

      // Extract final text response
      final finalResponse = _anthropicService.extractTextResponse(response);

      // Add system response message
      final systemMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: finalResponse,
        timestamp: DateTime.now(),
        type: MessageType.system,
      );

      // Add result
      final result = CommandResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        command: event.command,
        output: finalResponse,
        timestamp: DateTime.now(),
      );

      emit(state.copyWith(
        messages: [...state.messages, systemMessage],
        results: [...state.results, result],
        status: ChatStatus.idle,
      ));
    } catch (e) {
      final errorMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'Error: ${e.toString()}',
        timestamp: DateTime.now(),
        type: MessageType.system,
      );

      emit(state.copyWith(
        messages: [...state.messages, errorMessage],
        status: ChatStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
