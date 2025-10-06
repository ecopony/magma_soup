import 'package:flutter/material.dart';

class ToolResultContent extends StatelessWidget {
  final String result;

  const ToolResultContent({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Result:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        Text(
          result,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}
