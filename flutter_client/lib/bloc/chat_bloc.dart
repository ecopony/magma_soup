// ABOUTME: BLoC managing chat state and API server communication.
// ABOUTME: Consumes SSE streams from API server for real-time updates.

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';

import '../models/command_result.dart';
import '../models/geo_feature.dart';
import '../models/message.dart';
import '../models/sse_event.dart';
import '../services/api_client.dart';
import 'chat_event.dart';
import 'chat_state.dart';
import 'map_bloc.dart';
import 'map_event.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiClient _apiClient;
  final MapBloc _mapBloc;
  final Logger _logger;

  ChatBloc({
    required ApiClient apiClient,
    required MapBloc mapBloc,
    Logger? logger,
  })  : _apiClient = apiClient,
        _mapBloc = mapBloc,
        _logger = logger ?? Logger(),
        super(ChatState()) {
    on<SendCommand>(_onSendCommand);
    on<CreateConversation>(_onCreateConversation);
    on<LoadConversation>(_onLoadConversation);
  }

  Future<void> _onCreateConversation(
    CreateConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(state.copyWith(status: ChatStatus.loading));

      final conversation = await _apiClient.createConversation(
        title: event.title,
      );

      _logger.i('Created conversation: ${conversation.id}');

      emit(state.copyWith(
        conversationId: conversation.id,
        status: ChatStatus.idle,
      ));
    } catch (e) {
      _logger.e('Failed to create conversation: $e');
      emit(state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'Failed to create conversation: $e',
      ));
    }
  }

  Future<void> _onLoadConversation(
    LoadConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(state.copyWith(status: ChatStatus.loading));

      final conversation = await _apiClient.getConversation(event.conversationId);

      // Convert stored messages to UI messages
      final messages = conversation.messages.map((msg) {
        return Message(
          id: msg.id,
          text: msg.content.toString(),
          timestamp: msg.createdAt,
          type: msg.role == 'user' ? MessageType.user : MessageType.system,
        );
      }).toList();

      emit(state.copyWith(
        conversationId: conversation.id,
        messages: messages,
        status: ChatStatus.idle,
      ));
    } catch (e) {
      _logger.e('Failed to load conversation: $e');
      emit(state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'Failed to load conversation: $e',
      ));
    }
  }

  Future<void> _onSendCommand(
    SendCommand event,
    Emitter<ChatState> emit,
  ) async {
    // Ensure we have a conversation
    String? conversationId = state.conversationId;
    if (conversationId == null) {
      try {
        final conversation = await _apiClient.createConversation();
        conversationId = conversation.id;
        _logger.i('Auto-created conversation: $conversationId');
      } catch (e) {
        emit(state.copyWith(
          status: ChatStatus.error,
          errorMessage: 'Failed to create conversation: $e',
        ));
        return;
      }
    }

    // Add user message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: event.command,
      timestamp: DateTime.now(),
      type: MessageType.user,
    );

    final currentMessages = List<Message>.from(state.messages);
    currentMessages.add(userMessage);

    emit(state.copyWith(
      conversationId: conversationId,
      messages: currentMessages,
      status: ChatStatus.loading,
      isProcessing: true,
    ));

    // Track SSE events for result
    final llmHistory = <Map<String, dynamic>>[];
    final geoFeatures = <GeoFeature>[];
    final newMarkers = <Marker>[];
    String? finalResponse;

    try {
      // Stream events from API server
      final eventStream = _apiClient.sendMessage(
        conversationId: conversationId,
        message: event.command,
      );

      await for (final sseEvent in eventStream) {
        if (sseEvent is ToolCallEvent) {
          llmHistory.add({
            'type': 'tool_call',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'tool_name': sseEvent.toolName,
            'arguments': sseEvent.arguments,
          });

          // Emit intermediate state with loading indicator
          emit(state.copyWith(
            conversationId: conversationId,
            messages: currentMessages,
            status: ChatStatus.loading,
            isProcessing: true,
            currentToolCall: sseEvent.toolName,
          ));
        } else if (sseEvent is ToolResultEvent) {
          llmHistory.add({
            'type': 'tool_result',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'tool_name': sseEvent.toolName,
            'result': sseEvent.result,
          });
        } else if (sseEvent is ToolErrorEvent) {
          llmHistory.add({
            'type': 'tool_error',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'tool_name': sseEvent.toolName,
            'error': sseEvent.error,
          });
        } else if (sseEvent is LLMResponseEvent) {
          llmHistory.add({
            'type': 'llm_response',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'content': sseEvent.content, // Keep original structure for history
            'stop_reason': sseEvent.stopReason,
          });
        } else if (sseEvent is GeoFeatureEvent) {
          geoFeatures.add(sseEvent.feature);

          // Create marker for map
          final marker = Marker(
            point: LatLng(sseEvent.feature.lat, sseEvent.feature.lon),
            width: 80,
            height: 80,
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          );
          newMarkers.add(marker);
        } else if (sseEvent is DoneEvent) {
          finalResponse = sseEvent.finalResponse;
        } else if (sseEvent is ErrorEvent) {
          throw Exception(sseEvent.message);
        }
      }

      // Add assistant response
      final assistantMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: finalResponse ?? 'No response',
        timestamp: DateTime.now(),
        type: MessageType.system,
      );
      currentMessages.add(assistantMessage);

      // Create result
      final result = CommandResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        command: event.command,
        output: finalResponse ?? 'No response',
        timestamp: DateTime.now(),
        geoFeatures: geoFeatures,
        llmHistory: llmHistory,
      );

      // Send markers to MapBloc
      if (newMarkers.isNotEmpty) {
        _mapBloc.add(AddMarkers(newMarkers));
      }

      emit(state.copyWith(
        conversationId: conversationId,
        messages: currentMessages,
        results: [...state.results, result],
        status: ChatStatus.idle,
        llmInteractionHistory: [...state.llmInteractionHistory, ...llmHistory],
        isProcessing: false,
        currentToolCall: null,
      ));
    } catch (e) {
      _logger.e('Error during command execution: $e');

      final errorMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'Error: ${e.toString()}',
        timestamp: DateTime.now(),
        type: MessageType.system,
      );

      emit(state.copyWith(
        conversationId: conversationId,
        messages: [...currentMessages, errorMessage],
        status: ChatStatus.error,
        errorMessage: e.toString(),
        isProcessing: false,
        currentToolCall: null,
      ));
    }
  }

  @override
  Future<void> close() {
    _apiClient.dispose();
    return super.close();
  }
}
