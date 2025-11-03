import '../models/message.dart';
import '../models/command_result.dart';

enum ChatStatus { idle, loading, error }

class ChatState {
  final String? conversationId;
  final List<Message> messages;
  final List<CommandResult> results;
  final ChatStatus status;
  final String? errorMessage;
  final bool isProcessing;
  final String? currentToolCall;

  ChatState({
    this.conversationId,
    this.messages = const [],
    this.results = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.isProcessing = false,
    this.currentToolCall,
  });

  ChatState copyWith({
    String? conversationId,
    List<Message>? messages,
    List<CommandResult>? results,
    ChatStatus? status,
    String? errorMessage,
    bool? isProcessing,
    String? currentToolCall,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      results: results ?? this.results,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isProcessing: isProcessing ?? this.isProcessing,
      currentToolCall: currentToolCall ?? this.currentToolCall,
    );
  }
}
