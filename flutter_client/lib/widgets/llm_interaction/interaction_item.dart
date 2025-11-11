import 'package:flutter/material.dart';

import '../../models/message.dart' as models;
import 'content/llm_response_content.dart';
import 'content/tool_call_content.dart';
import 'content/tool_error_content.dart';
import 'content/tool_result_content.dart';
import 'content/user_prompt_content.dart';

class InteractionItem extends StatelessWidget {
  final models.Message message;

  const InteractionItem({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final styling = _getItemStyling();

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
          _formatTimestamp(message.timestamp),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  _ItemStyling _getItemStyling() {
    switch (message.kind) {
      case models.MessageKind.userPrompt:
        return _ItemStyling(
          backgroundColor: Colors.blue.shade50,
          icon: Icons.person,
          title: 'User Prompt',
        );
      case models.MessageKind.llmResponse:
        return _ItemStyling(
          backgroundColor: Colors.purple.shade50,
          icon: Icons.psychology,
          title: 'LLM Response',
        );
      case models.MessageKind.toolCall:
        final toolCall = message.content as models.ToolCallContent;
        return _ItemStyling(
          backgroundColor: Colors.orange.shade50,
          icon: Icons.build,
          title: 'Tool Call: ${toolCall.toolName}',
        );
      case models.MessageKind.toolResult:
        final toolResult = message.content as models.ToolResultContent;
        return _ItemStyling(
          backgroundColor: Colors.green.shade50,
          icon: Icons.check_circle,
          title: 'Tool Result: ${toolResult.toolName}',
        );
      case models.MessageKind.toolError:
        final toolError = message.content as models.ToolErrorContent;
        return _ItemStyling(
          backgroundColor: Colors.red.shade50,
          icon: Icons.error,
          title: 'Tool Error: ${toolError.toolName}',
        );
      case models.MessageKind.geoFeature:
        final geoContent = message.content as models.GeoFeatureContent;
        return _ItemStyling(
          backgroundColor: Colors.teal.shade50,
          icon: Icons.location_on,
          title:
              'Geographic Feature: ${geoContent.feature.label ?? geoContent.feature.type}',
        );
      case models.MessageKind.removeGeoFeature:
        return _ItemStyling(
          backgroundColor: Colors.orange.shade50,
          icon: Icons.delete_outline,
          title: 'Remove Geographic Feature',
        );
      case models.MessageKind.error:
        return _ItemStyling(
          backgroundColor: Colors.red.shade100,
          icon: Icons.warning,
          title: 'Error',
        );
      case models.MessageKind.user:
      case models.MessageKind.assistant:
        // These shouldn't appear in interaction viewer
        return _ItemStyling(
          backgroundColor: Colors.grey.shade50,
          icon: Icons.info,
          title: 'Conversation Message',
        );
    }
  }

  Widget _buildContent() {
    switch (message.kind) {
      case models.MessageKind.userPrompt:
        final content = message.content as models.UserPromptContent;
        return UserPromptContent(content: content.prompt);
      case models.MessageKind.llmResponse:
        final content = message.content as models.LLMResponseContent;
        return LlmResponseContent(
          stopReason: content.stopReason ?? '',
          content: content.content,
        );
      case models.MessageKind.toolCall:
        final content = message.content as models.ToolCallContent;
        return ToolCallContent(
          toolName: content.toolName,
          arguments: content.arguments,
        );
      case models.MessageKind.toolResult:
        final content = message.content as models.ToolResultContent;
        return ToolResultContent(result: content.result);
      case models.MessageKind.toolError:
        final content = message.content as models.ToolErrorContent;
        return ToolErrorContent(error: content.error);
      case models.MessageKind.geoFeature:
        final content = message.content as models.GeoFeatureContent;
        return Text(
          'Feature: ${content.feature.label ?? content.feature.type}\n'
          'Lat: ${content.feature.lat}, Lon: ${content.feature.lon}',
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        );
      case models.MessageKind.removeGeoFeature:
        final content = message.content as models.RemoveGeoFeatureContent;
        return Text(
          'Removed feature ID: ${content.featureId}',
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        );
      case models.MessageKind.error:
        final content = message.content as models.TextContent;
        return Text(
          content.text,
          style: const TextStyle(fontSize: 11, color: Colors.red),
        );
      case models.MessageKind.user:
      case models.MessageKind.assistant:
        final content = message.content as models.TextContent;
        return Text(
          content.text,
          style: const TextStyle(fontSize: 11),
        );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
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
