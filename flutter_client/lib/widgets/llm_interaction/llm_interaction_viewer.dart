import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/agentic_trace_bloc.dart';
import '../../bloc/agentic_trace_state.dart';
import 'interaction_item.dart';

class LlmInteractionViewer extends StatefulWidget {
  const LlmInteractionViewer({
    super.key,
  });

  @override
  State<LlmInteractionViewer> createState() => _LlmInteractionViewerState();
}

class _LlmInteractionViewerState extends State<LlmInteractionViewer> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgenticTraceBloc, AgenticTraceState>(
      builder: (context, state) {
        if (state.trace.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LLM Interaction History',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${state.trace.length} events',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExpanded)
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.trace.length,
                    itemBuilder: (context, index) {
                      final interaction = state.trace[index];
                      return InteractionItem(interaction: interaction);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
