import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_state.dart';
import '../llm_interaction/llm_interaction_viewer.dart';
import 'result_card.dart';

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
