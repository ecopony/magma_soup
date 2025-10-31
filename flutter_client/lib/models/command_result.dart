class CommandResult {
  final String id;
  final String command;
  final String output;
  final DateTime timestamp;

  CommandResult({
    required this.id,
    required this.command,
    required this.output,
    required this.timestamp,
  });
}
