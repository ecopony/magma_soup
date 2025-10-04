import 'package:bloc/bloc.dart';
import '../models/message.dart';
import '../models/command_result.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc() : super(ChatState()) {
    on<SendCommand>(_onSendCommand);
  }

  void _onSendCommand(SendCommand event, Emitter<ChatState> emit) {
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: event.command,
      timestamp: DateTime.now(),
      type: MessageType.user,
    );

    final systemMessage = Message(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      text: 'Processing command: ${event.command}',
      timestamp: DateTime.now(),
      type: MessageType.system,
    );

    final result = CommandResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      command: event.command,
      output: 'Command executed: ${event.command}\nOutput will appear here.',
      timestamp: DateTime.now(),
    );

    emit(state.copyWith(
      messages: [...state.messages, userMessage, systemMessage],
      results: [...state.results, result],
    ));
  }
}
