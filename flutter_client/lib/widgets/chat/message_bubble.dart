import 'package:flutter/material.dart';
import '../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.kind == MessageKind.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFF268bd2) // blue
                  : const Color(0xFF93a1a1), // base1
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.displayText,
              style: const TextStyle(
                color: Color(0xFFfdf6e3), // base3
              ),
            ),
          ),
        ],
      ),
    );
  }
}
