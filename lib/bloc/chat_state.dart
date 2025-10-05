import '../models/message.dart';
import '../models/command_result.dart';

enum ChatStatus { idle, loading, error }

class ChatState {
  final List<Message> messages;
  final List<CommandResult> results;
  final ChatStatus status;
  final String? errorMessage;

  ChatState({
    this.messages = const [],
    this.results = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
  });

  ChatState copyWith({
    List<Message>? messages,
    List<CommandResult>? results,
    ChatStatus? status,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      results: results ?? this.results,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
