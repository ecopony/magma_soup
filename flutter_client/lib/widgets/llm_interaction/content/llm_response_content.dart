import 'package:flutter/material.dart';
import 'dart:convert';

class LlmResponseContent extends StatelessWidget {
  final String stopReason;
  final dynamic content;

  const LlmResponseContent({
    super.key,
    required this.stopReason,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
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
