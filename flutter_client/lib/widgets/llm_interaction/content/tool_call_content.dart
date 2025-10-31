import 'package:flutter/material.dart';
import 'dart:convert';

class ToolCallContent extends StatelessWidget {
  final String toolName;
  final Map<String, dynamic> arguments;

  const ToolCallContent({
    super.key,
    required this.toolName,
    required this.arguments,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tool: $toolName',
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
          _formatJson(arguments),
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ],
    );
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
