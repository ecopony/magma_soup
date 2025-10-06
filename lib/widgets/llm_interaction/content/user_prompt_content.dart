import 'package:flutter/material.dart';

class UserPromptContent extends StatelessWidget {
  final String content;

  const UserPromptContent({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Text(
      content,
      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
    );
  }
}
