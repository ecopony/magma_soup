import 'package:flutter/material.dart';

class ToolErrorContent extends StatelessWidget {
  final String error;

  const ToolErrorContent({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Error:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        Text(
          error,
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}
