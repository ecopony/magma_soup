// ABOUTME: BLoC managing chat state and API server communication.
// ABOUTME: Consumes SSE streams from API server for real-time updates.

import 'package:bloc/bloc.dart';
import 'package:logger/logger.dart';

import '../models/message.dart';
import '../models/sse_event.dart';
import '../services/api_client.dart';
import '../services/message_decoder.dart';
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

      final conversation =
          await _apiClient.getConversation(event.conversationId);

      // Convert stored messages to UI messages
      final messages = conversation.messages.map((msg) {
        return Message(
          id: msg.id,
          kind: msg.role == 'user' ? MessageKind.user : MessageKind.assistant,
          content: TextContent(msg.content.toString()),
          timestamp: msg.createdAt,
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
      kind: MessageKind.user,
      content: TextContent(event.command),
      timestamp: DateTime.now(),
    );

    final currentMessages = List<Message>.from(state.messages);
    currentMessages.add(userMessage);

    emit(state.copyWith(
      conversationId: conversationId,
      messages: currentMessages,
      status: ChatStatus.loading,
    ));

    String? finalResponse;

    try {
      // Stream events from API server
      final eventStream = _apiClient.sendMessage(
        conversationId: conversationId,
        message: event.command,
      );

      await for (final sseEvent in eventStream) {
        // Decode event to message
        final message = MessageDecoder.decode(sseEvent);
        if (message != null) {
          currentMessages.add(message);

          // Handle GeoFeature - send to map bloc
          if (message.kind == MessageKind.geoFeature) {
            final geoContent = message.content as GeoFeatureContent;
            _mapBloc.add(AddGeoFeature(geoContent.feature));
          }

          // Handle ToolCall - update current tool for UI feedback
          if (message.kind == MessageKind.toolCall) {
            final toolContent = message.content as ToolCallContent;
            emit(state.copyWith(
              messages: List.from(currentMessages),
              currentToolCall: toolContent.toolName,
            ));
          } else {
            emit(state.copyWith(messages: List.from(currentMessages)));
          }
        }

        // Track final response
        if (sseEvent is DoneEvent) {
          finalResponse = sseEvent.finalResponse;
        }

        // Handle error events
        if (sseEvent is ErrorEvent) {
          throw Exception(sseEvent.message);
        }
      }

      // Add assistant response
      final assistantMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        kind: MessageKind.assistant,
        content: TextContent(finalResponse ?? 'No response'),
        timestamp: DateTime.now(),
      );
      currentMessages.add(assistantMessage);

      emit(state.copyWith(
        conversationId: conversationId,
        messages: currentMessages,
        status: ChatStatus.idle,
        currentToolCall: null,
      ));
    } catch (e) {
      _logger.e('Error during command execution: $e');

      final errorMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        kind: MessageKind.error,
        content: TextContent('Error: ${e.toString()}'),
        timestamp: DateTime.now(),
      );

      emit(state.copyWith(
        conversationId: conversationId,
        messages: [...currentMessages, errorMessage],
        status: ChatStatus.error,
        errorMessage: e.toString(),
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
