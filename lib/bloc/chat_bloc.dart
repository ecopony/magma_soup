import 'package:bloc/bloc.dart';
import '../models/message.dart';
import '../models/command_result.dart';
import '../services/anthropic_service.dart';
import '../services/gis_prompt_builder.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final AnthropicService _anthropicService;

  ChatBloc({AnthropicService? anthropicService})
      : _anthropicService = anthropicService ?? AnthropicService(),
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

      // Call Anthropic API
      final response = await _anthropicService.sendMessage(prompt: prompt);

      // Add system response message
      final systemMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response,
        timestamp: DateTime.now(),
        type: MessageType.system,
      );

      // Add result
      final result = CommandResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        command: event.command,
        output: response,
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
