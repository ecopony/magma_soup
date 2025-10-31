import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/chat_bloc.dart';
import '../../bloc/chat_state.dart';
import '../llm_interaction/llm_interaction_viewer.dart';
import '../map/map_widget.dart';

class ResultsPane extends StatelessWidget {
  const ResultsPane({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        return Column(
          children: [
            // Map at top (fixed, doesn't scroll)
            const MapWidget(),
            // LLM interaction history (scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: LlmInteractionViewer(
                  interactions: state.llmInteractionHistory,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
