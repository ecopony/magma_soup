import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_event.dart';
import '../../bloc/chat_state.dart';
import 'loading_indicator.dart';
import 'message_bubble.dart';

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
              final conversationMessages = state.messages
                  .where((m) => m.isConversationMessage)
                  .toList();
              return Stack(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: conversationMessages.length,
                    itemBuilder: (context, index) {
                      final message = conversationMessages[index];
                      return MessageBubble(message: message);
                    },
                  ),
                  if (state.status == ChatStatus.loading)
                    const LoadingIndicator(),
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
