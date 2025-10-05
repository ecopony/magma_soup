import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../models/message.dart';

class ChatPane extends StatefulWidget {
  const ChatPane({super.key});

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<ChatBloc, ChatState>(
            builder: (context, state) {
              return Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return MessageBubble(message: message);
                    },
                  ),
                  if (state.status == ChatStatus.loading)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFfdf6e3),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF268bd2),
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Processing...'),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        BlocBuilder<ChatBloc, ChatState>(
          builder: (context, state) {
            final isLoading = state.status == ChatStatus.loading;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
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
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        hintText: 'Enter GIS command...',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Color(0xFFeee8d5), // base2
                      ),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty && !isLoading) {
                          context.read<ChatBloc>().add(SendCommand(value));
                          _controller.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            final value = _controller.text;
                            if (value.trim().isNotEmpty) {
                              context.read<ChatBloc>().add(SendCommand(value));
                              _controller.clear();
                            }
                          },
                    icon: const Icon(Icons.send),
                    color: const Color(0xFF268bd2), // blue
                  ),
                ],
              ),
            );
          },
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
              message.text,
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
