enum MessageType { user, system }

class Message {
  final String id;
  final String text;
  final DateTime timestamp;
  final MessageType type;

  Message({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.type,
  });
}
