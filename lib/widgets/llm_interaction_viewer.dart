import 'package:flutter/material.dart';
import 'dart:convert';

class LlmInteractionViewer extends StatefulWidget {
  final List<Map<String, dynamic>> interactions;

  const LlmInteractionViewer({
    super.key,
    required this.interactions,
  });

  @override
  State<LlmInteractionViewer> createState() => _LlmInteractionViewerState();
}

class _LlmInteractionViewerState extends State<LlmInteractionViewer> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.interactions.isEmpty) {
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
                      '${widget.interactions.length} events',
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
                itemCount: widget.interactions.length,
                itemBuilder: (context, index) {
                  final interaction = widget.interactions[index];
                  return _buildInteractionItem(interaction, index);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInteractionItem(Map<String, dynamic> interaction, int index) {
    final type = interaction['type'] as String? ?? 'unknown';
    final timestamp = interaction['timestamp'] as String? ?? '';

    Color backgroundColor;
    IconData icon;
    String title;

    switch (type) {
      case 'user_prompt':
        backgroundColor = Colors.blue.shade50;
        icon = Icons.person;
        title = 'User Prompt';
        break;
      case 'llm_response':
        backgroundColor = Colors.purple.shade50;
        icon = Icons.psychology;
        title = 'LLM Response';
        break;
      case 'tool_call':
        backgroundColor = Colors.orange.shade50;
        icon = Icons.build;
        title = 'Tool Call: ${interaction['tool_name']}';
        break;
      case 'tool_result':
        backgroundColor = Colors.green.shade50;
        icon = Icons.check_circle;
        title = 'Tool Result: ${interaction['tool_name']}';
        break;
      case 'tool_error':
        backgroundColor = Colors.red.shade50;
        icon = Icons.error;
        title = 'Tool Error: ${interaction['tool_name']}';
        break;
      default:
        backgroundColor = Colors.grey.shade50;
        icon = Icons.info;
        title = type;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        leading: Icon(icon, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatTimestamp(timestamp),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: _buildInteractionContent(interaction, type),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionContent(
      Map<String, dynamic> interaction, String type) {
    switch (type) {
      case 'user_prompt':
        return Text(
          interaction['content'] as String? ?? '',
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        );

      case 'llm_response':
        final stopReason = interaction['stop_reason'] ?? '';
        final content = interaction['content'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stop Reason: $stopReason',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatJson(content),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        );

      case 'tool_call':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tool: ${interaction['tool_name']}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Arguments:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              _formatJson(interaction['arguments']),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        );

      case 'tool_result':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Result:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              interaction['result'] as String? ?? '',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        );

      case 'tool_error':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Error:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
            Text(
              interaction['error'] as String? ?? '',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.red,
              ),
            ),
          ],
        );

      default:
        return Text(
          _formatJson(interaction),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        );
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  String _formatJson(dynamic data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      return data.toString();
    }
  }
}
