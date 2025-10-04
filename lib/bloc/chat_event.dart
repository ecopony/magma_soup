abstract class ChatEvent {}

class SendCommand extends ChatEvent {
  final String command;

  SendCommand(this.command);
}
