import '../models/message.dart';
import '../models/command_result.dart';

class ChatState {
  final List<Message> messages;
  final List<CommandResult> results;

  ChatState({
    this.messages = const [],
    this.results = const [],
  });

  ChatState copyWith({
    List<Message>? messages,
    List<CommandResult>? results,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      results: results ?? this.results,
    );
  }
}
