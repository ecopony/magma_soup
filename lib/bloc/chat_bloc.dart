import 'package:bloc/bloc.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/command_result.dart';
import '../models/message.dart';
import '../services/anthropic_service.dart';
import '../services/geo_feature_extractor.dart';
import '../services/gis_prompt_builder.dart';
import '../services/mcp_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import 'map_bloc.dart';
import 'map_event.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AnthropicService _anthropicService;
  final McpService _mcpService;
  final GeoFeatureExtractor _geoFeatureExtractor;
  final MapBloc _mapBloc;

  ChatBloc({
    AnthropicService? anthropicService,
    McpService? mcpService,
    GeoFeatureExtractor? geoFeatureExtractor,
    required MapBloc mapBloc,
  })  : _anthropicService = anthropicService ?? AnthropicService(),
        _mcpService = mcpService ?? McpService(),
        _geoFeatureExtractor = geoFeatureExtractor ?? GeoFeatureExtractor(),
        _mapBloc = mapBloc,
        super(ChatState()) {
    on<SendCommand>(_onSendCommand);
  }

  Future<void> _onSendCommand(
      SendCommand event, Emitter<ChatState> emit) async {
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

      // Track full LLM interaction for debugging/display
      final llmHistory = <Map<String, dynamic>>[
        {
          'type': 'user_prompt',
          'timestamp': DateTime.now().toIso8601String(),
          'content': prompt,
        },
        {
          'type': 'llm_response',
          'timestamp': DateTime.now().toIso8601String(),
          'stop_reason': response['stop_reason'],
          'content': response['content'],
        },
      ];

      int toolCallCount = 0;
      const maxToolCalls = 10;
      final newMarkers = <Marker>[];

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

            // Track tool call and result in history
            llmHistory.add({
              'type': 'tool_call',
              'timestamp': DateTime.now().toIso8601String(),
              'tool_name': toolName,
              'arguments': toolInput,
            });
            llmHistory.add({
              'type': 'tool_result',
              'timestamp': DateTime.now().toIso8601String(),
              'tool_name': toolName,
              'result': result,
            });

            // Extract geographic features from tool results
            final markers = _geoFeatureExtractor.extractMarkers(
              toolName: toolName,
              result: result,
              arguments: toolInput,
            );
            newMarkers.addAll(markers);
          } catch (e) {
            toolResults.add({
              'type': 'tool_result',
              'tool_use_id': toolUseId,
              'content': 'Error: ${e.toString()}',
              'is_error': true,
            });

            // Track tool error in history
            llmHistory.add({
              'type': 'tool_call',
              'timestamp': DateTime.now().toIso8601String(),
              'tool_name': toolName,
              'arguments': toolInput,
            });
            llmHistory.add({
              'type': 'tool_error',
              'timestamp': DateTime.now().toIso8601String(),
              'tool_name': toolName,
              'error': e.toString(),
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

        // Track subsequent LLM response
        llmHistory.add({
          'type': 'llm_response',
          'timestamp': DateTime.now().toIso8601String(),
          'stop_reason': response['stop_reason'],
          'content': response['content'],
        });
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

      // Send markers to MapBloc
      if (newMarkers.isNotEmpty) {
        _mapBloc.add(AddMarkers(newMarkers));
      }

      emit(state.copyWith(
        messages: [...state.messages, systemMessage],
        results: [...state.results, result],
        status: ChatStatus.idle,
        llmInteractionHistory: [...state.llmInteractionHistory, ...llmHistory],
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
