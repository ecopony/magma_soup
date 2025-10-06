import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../bloc/chat_state.dart';
import '../models/command_result.dart';
import 'llm_interaction_viewer.dart';

class ResultsPane extends StatelessWidget {
  const ResultsPane({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        if (state.results.isEmpty) {
          return const Center(
            child: Text(
              'No results yet',
              style: TextStyle(
                color: Color(0xFF93a1a1), // base1
                fontSize: 16,
              ),
            ),
          );
        }

        return Column(
          children: [
            // LLM Interaction Viewer at the top
            LlmInteractionViewer(
              interactions: state.llmInteractionHistory,
            ),
            // Results list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.results.length,
                itemBuilder: (context, index) {
                  final result = state.results[index];
                  return ResultCard(result: result);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ResultCard extends StatelessWidget {
  final CommandResult result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFFfdf6e3), // base3
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.terminal,
                  size: 16,
                  color: Color(0xFF268bd2), // blue
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.command,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF268bd2), // blue
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatTimestamp(result.timestamp),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF93a1a1), // base1
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFeee8d5), // base2
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                result.output,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF657b83), // base00
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}
