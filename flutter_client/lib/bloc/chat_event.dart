abstract class ChatEvent {}

class SendCommand extends ChatEvent {
  final String command;

  SendCommand(this.command);
}

class CreateConversation extends ChatEvent {
  final String? title;

  CreateConversation({this.title});
}

class LoadConversation extends ChatEvent {
  final String conversationId;

  LoadConversation(this.conversationId);
}
