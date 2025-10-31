import '../models/message.dart';
import '../models/command_result.dart';

enum ChatStatus { idle, loading, error }

class ChatState {
  final List<Message> messages;
  final List<CommandResult> results;
  final ChatStatus status;
  final String? errorMessage;
  final List<Map<String, dynamic>> llmInteractionHistory;

  ChatState({
    this.messages = const [],
    this.results = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.llmInteractionHistory = const [],
  });

  ChatState copyWith({
    List<Message>? messages,
    List<CommandResult>? results,
    ChatStatus? status,
    String? errorMessage,
    List<Map<String, dynamic>>? llmInteractionHistory,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      results: results ?? this.results,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      llmInteractionHistory:
          llmInteractionHistory ?? this.llmInteractionHistory,
    );
  }
}
