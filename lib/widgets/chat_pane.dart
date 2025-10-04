import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../models/message.dart';

class ChatPane extends StatelessWidget {
  ChatPane({super.key});

  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final message = state.messages[index];
                  return MessageBubble(message: message);
                },
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color(0xFFfdf6e3), // base3
            border: Border(
              top: BorderSide(
                color: Color(0xFF93a1a1), // base1
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Enter command...',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFeee8d5), // base2
                  ),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      context.read<ChatBloc>().add(SendCommand(value));
                      _controller.clear();
                    }
                  },
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  final value = _controller.text;
                  if (value.trim().isNotEmpty) {
                    context.read<ChatBloc>().add(SendCommand(value));
                    _controller.clear();
                  }
                },
                icon: Icon(Icons.send),
                color: Color(0xFF268bd2), // blue
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: 300),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser
                  ? Color(0xFF268bd2) // blue
                  : Color(0xFF93a1a1), // base1
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: Color(0xFFfdf6e3), // base3
              ),
            ),
          ),
        ],
      ),
    );
  }
}
