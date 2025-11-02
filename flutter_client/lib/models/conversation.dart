// ABOUTME: Conversation metadata models for API server communication.
// ABOUTME: Represents conversation history and stored messages.

/// Conversation metadata from API server.
class Conversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? title;

  Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      title: json['title'],
    );
  }
}

/// Conversation with full message history.
class ConversationDetail extends Conversation {
  final List<ConversationMessage> messages;

  ConversationDetail({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.title,
    required this.messages,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      title: json['title'],
      messages: (json['messages'] as List)
          .map((msg) => ConversationMessage.fromJson(msg))
          .toList(),
    );
  }
}

class ConversationMessage {
  final String id;
  final String role;
  final dynamic content;
  final DateTime createdAt;
  final int sequenceNumber;

  ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.sequenceNumber,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      sequenceNumber: json['sequence_number'],
    );
  }
}
