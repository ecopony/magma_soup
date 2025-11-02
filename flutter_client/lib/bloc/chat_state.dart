import '../models/message.dart';
import '../models/command_result.dart';

enum ChatStatus { idle, loading, error }

class ChatState {
  final String? conversationId;
  final List<Message> messages;
  final List<CommandResult> results;
  final ChatStatus status;
  final String? errorMessage;
  final List<Map<String, dynamic>> llmInteractionHistory;
  final bool isProcessing;
  final String? currentToolCall;

  ChatState({
    this.conversationId,
    this.messages = const [],
    this.results = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.llmInteractionHistory = const [],
    this.isProcessing = false,
    this.currentToolCall,
  });

  ChatState copyWith({
    String? conversationId,
    List<Message>? messages,
    List<CommandResult>? results,
    ChatStatus? status,
    String? errorMessage,
    List<Map<String, dynamic>>? llmInteractionHistory,
    bool? isProcessing,
    String? currentToolCall,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      results: results ?? this.results,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      llmInteractionHistory:
          llmInteractionHistory ?? this.llmInteractionHistory,
      isProcessing: isProcessing ?? this.isProcessing,
      currentToolCall: currentToolCall ?? this.currentToolCall,
    );
  }
}
