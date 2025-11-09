import '../models/message.dart';

enum ChatStatus { idle, loading, error }

class ChatState {
  final String? conversationId;
  final List<Message> messages;
  final ChatStatus status;
  final String? errorMessage;
  final String? currentToolCall;

  ChatState({
    this.conversationId,
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.errorMessage,
    this.currentToolCall,
  });

  List<Message> get conversationMessages =>
      messages.where((m) => m.isConversationMessage).toList();

  ChatState copyWith({
    String? conversationId,
    List<Message>? messages,
    ChatStatus? status,
    String? errorMessage,
    String? currentToolCall,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      currentToolCall: currentToolCall ?? this.currentToolCall,
    );
  }
}
