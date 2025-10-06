import 'package:flutter/material.dart';
import 'content/user_prompt_content.dart';
import 'content/llm_response_content.dart';
import 'content/tool_call_content.dart';
import 'content/tool_result_content.dart';
import 'content/tool_error_content.dart';
import 'dart:convert';

class InteractionItem extends StatelessWidget {
  final Map<String, dynamic> interaction;

  const InteractionItem({super.key, required this.interaction});

  @override
  Widget build(BuildContext context) {
    final type = interaction['type'] as String? ?? 'unknown';
    final timestamp = interaction['timestamp'] as String? ?? '';

    final styling = _getItemStyling(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: styling.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        leading: Icon(styling.icon, size: 20),
        title: Text(
          styling.title,
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
            child: _buildContent(type),
          ),
        ],
      ),
    );
  }

  _ItemStyling _getItemStyling(String type) {
    switch (type) {
      case 'user_prompt':
        return _ItemStyling(
          backgroundColor: Colors.blue.shade50,
          icon: Icons.person,
          title: 'User Prompt',
        );
      case 'llm_response':
        return _ItemStyling(
          backgroundColor: Colors.purple.shade50,
          icon: Icons.psychology,
          title: 'LLM Response',
        );
      case 'tool_call':
        return _ItemStyling(
          backgroundColor: Colors.orange.shade50,
          icon: Icons.build,
          title: 'Tool Call: ${interaction['tool_name']}',
        );
      case 'tool_result':
        return _ItemStyling(
          backgroundColor: Colors.green.shade50,
          icon: Icons.check_circle,
          title: 'Tool Result: ${interaction['tool_name']}',
        );
      case 'tool_error':
        return _ItemStyling(
          backgroundColor: Colors.red.shade50,
          icon: Icons.error,
          title: 'Tool Error: ${interaction['tool_name']}',
        );
      default:
        return _ItemStyling(
          backgroundColor: Colors.grey.shade50,
          icon: Icons.info,
          title: type,
        );
    }
  }

  Widget _buildContent(String type) {
    switch (type) {
      case 'user_prompt':
        return UserPromptContent(
          content: interaction['content'] as String? ?? '',
        );

      case 'llm_response':
        return LlmResponseContent(
          stopReason: interaction['stop_reason'] ?? '',
          content: interaction['content'],
        );

      case 'tool_call':
        return ToolCallContent(
          toolName: interaction['tool_name'] as String? ?? '',
          arguments: interaction['arguments'] as Map<String, dynamic>? ?? {},
        );

      case 'tool_result':
        return ToolResultContent(
          result: interaction['result'] as String? ?? '',
        );

      case 'tool_error':
        return ToolErrorContent(
          error: interaction['error'] as String? ?? '',
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

class _ItemStyling {
  final Color backgroundColor;
  final IconData icon;
  final String title;

  _ItemStyling({
    required this.backgroundColor,
    required this.icon,
    required this.title,
  });
}
