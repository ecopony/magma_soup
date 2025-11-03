import 'package:flutter/material.dart';

import '../llm_interaction/llm_interaction_viewer.dart';
import '../map/map_widget.dart';

class ResultsPane extends StatelessWidget {
  const ResultsPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // Map at top (fixed, doesn't scroll)
        MapWidget(),
        // LLM interaction history (scrollable)
        Expanded(
          child: SingleChildScrollView(
            child: LlmInteractionViewer(),
          ),
        ),
      ],
    );
  }
}
