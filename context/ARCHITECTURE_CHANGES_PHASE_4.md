# Phase 4: Flutter Client Updates

## Overview
Update the Flutter client to remove the Anthropic API integration and agentic loop, replacing it with SSE-based communication to the API server. This completes the architecture migration by making the Flutter app a pure UI client.

---

## Current State (Before Phase 4)

The Flutter client currently:
- **Has direct Anthropic API integration** via `AnthropicService`
- **Runs agentic loop locally** in `ChatBloc._onSendCommand` (lines 86-179)
- **Stores API key locally** in `.env` file
- **Calls MCP server directly** via `MCPService`
- **Has its own tool execution logic**

After Phase 4, the Flutter client will:
- **Communicate only with API server** (no Anthropic SDK)
- **Consume SSE streams** for real-time updates
- **Have zero API keys** (security improvement)
- **Be a pure presentation layer**

---

## Goals

### Primary Objectives
1. **Remove direct Anthropic API integration** - Delete `AnthropicService` and Anthropic SDK dependency
2. **Replace agentic loop with API client** - Remove local orchestration, consume API server's SSE stream
3. **Remove API keys** - Delete ANTHROPIC_API_KEY from `.env` and environment loading
4. **Simplify ChatBloc** - Transform from orchestrator to stream consumer

### Secondary Objectives
1. **Add conversation management UI** - List and select previous conversations
2. **Improve error handling** - Better UX for network failures and API errors
3. **Add loading states** - Show intermediate tool execution progress
4. **Maintain feature parity** - All existing features work through new architecture

---

## Step 1: Add SSE Client Dependency

### 1.1 Choose SSE Package

**Options:**
- `http` package (already installed) - Supports streaming responses natively
- `sse_client` - Dedicated SSE client (not actively maintained)
- `eventsource` - Another SSE option (actively maintained)

**Recommendation**: Use existing `http` package with streaming support. No additional dependency needed.

### 1.2 Verify http Package Capabilities

The `http` package (v1.5.0) already supports streaming responses via `StreamedResponse`. No additional dependencies required.

---

## Step 2: Create API Client Service

### 2.1 Create `lib/services/api_client.dart`

This service will replace both `AnthropicService` and direct MCP calls.

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sse_event.dart';
import '../models/conversation.dart';
import '../models/message.dart' as models;

/// Client for communicating with the API server.
/// Handles conversation management and SSE streaming.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Creates a new conversation.
  Future<Conversation> createConversation({String? title}) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/conversations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to create conversation: ${response.body}');
    }

    return Conversation.fromJson(jsonDecode(response.body));
  }

  /// Lists recent conversations.
  Future<List<Conversation>> listConversations({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/conversations?limit=$limit&offset=$offset'),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to list conversations: ${response.body}');
    }

    final List<dynamic> json = jsonDecode(response.body);
    return json.map((item) => Conversation.fromJson(item)).toList();
  }

  /// Gets a conversation with its full message history.
  Future<ConversationDetail> getConversation(String conversationId) async {
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/conversations/$conversationId'),
    );

    if (response.statusCode == 404) {
      throw ConversationNotFoundException(conversationId);
    } else if (response.statusCode != 200) {
      throw ApiException('Failed to get conversation: ${response.body}');
    }

    return ConversationDetail.fromJson(jsonDecode(response.body));
  }

  /// Sends a message and streams SSE events.
  ///
  /// Returns a stream of SSE events including tool calls, tool results,
  /// and the final response.
  Stream<SSEEvent> sendMessage({
    required String conversationId,
    required String message,
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/conversations/$conversationId/messages'),
    );

    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'message': message});

    final streamedResponse = await _httpClient.send(request);

    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw ApiException('Failed to send message: $body');
    }

    // Parse SSE stream
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      // SSE format: "event: eventType\ndata: {...}\n\n"
      final lines = chunk.split('\n');
      String? eventType;
      String? data;

      for (final line in lines) {
        if (line.startsWith('event: ')) {
          eventType = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          data = line.substring(6).trim();
        } else if (line.isEmpty && eventType != null && data != null) {
          // Complete event received
          yield SSEEvent.fromRaw(eventType, data);
          eventType = null;
          data = null;
        }
      }
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

class ConversationNotFoundException implements Exception {
  final String conversationId;
  ConversationNotFoundException(this.conversationId);

  @override
  String toString() => 'Conversation not found: $conversationId';
}
```

### 2.2 Create `lib/models/sse_event.dart`

Define SSE event types from the API server:

```dart
import 'dart:convert';
import 'geo_feature.dart';

/// Events streamed from the API server during message processing.
abstract class SSEEvent {
  final DateTime timestamp;

  SSEEvent({DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  factory SSEEvent.fromRaw(String eventType, String data) {
    final Map<String, dynamic> json = jsonDecode(data);

    switch (eventType) {
      case 'tool_call':
        return ToolCallEvent.fromJson(json);
      case 'tool_result':
        return ToolResultEvent.fromJson(json);
      case 'tool_error':
        return ToolErrorEvent.fromJson(json);
      case 'llm_response':
        return LLMResponseEvent.fromJson(json);
      case 'geo_feature':
        return GeoFeatureEvent.fromJson(json);
      case 'done':
        return DoneEvent.fromJson(json);
      case 'error':
        return ErrorEvent.fromJson(json);
      default:
        throw UnknownEventException(eventType);
    }
  }
}

class ToolCallEvent extends SSEEvent {
  final String toolName;
  final Map<String, dynamic> arguments;
  final String toolUseId;

  ToolCallEvent({
    required this.toolName,
    required this.arguments,
    required this.toolUseId,
    super.timestamp,
  });

  factory ToolCallEvent.fromJson(Map<String, dynamic> json) {
    return ToolCallEvent(
      toolName: json['tool_name'],
      arguments: json['arguments'],
      toolUseId: json['tool_use_id'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ToolResultEvent extends SSEEvent {
  final String toolName;
  final String result;
  final String toolUseId;

  ToolResultEvent({
    required this.toolName,
    required this.result,
    required this.toolUseId,
    super.timestamp,
  });

  factory ToolResultEvent.fromJson(Map<String, dynamic> json) {
    return ToolResultEvent(
      toolName: json['tool_name'],
      result: json['result'],
      toolUseId: json['tool_use_id'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ToolErrorEvent extends SSEEvent {
  final String toolName;
  final String error;
  final String toolUseId;

  ToolErrorEvent({
    required this.toolName,
    required this.error,
    required this.toolUseId,
    super.timestamp,
  });

  factory ToolErrorEvent.fromJson(Map<String, dynamic> json) {
    return ToolErrorEvent(
      toolName: json['tool_name'],
      error: json['error'],
      toolUseId: json['tool_use_id'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class LLMResponseEvent extends SSEEvent {
  final String content;
  final String? stopReason;

  LLMResponseEvent({
    required this.content,
    this.stopReason,
    super.timestamp,
  });

  factory LLMResponseEvent.fromJson(Map<String, dynamic> json) {
    return LLMResponseEvent(
      content: json['content'],
      stopReason: json['stop_reason'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class GeoFeatureEvent extends SSEEvent {
  final GeoFeature feature;

  GeoFeatureEvent({
    required this.feature,
    super.timestamp,
  });

  factory GeoFeatureEvent.fromJson(Map<String, dynamic> json) {
    return GeoFeatureEvent(
      feature: GeoFeature.fromJson(json['feature']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class DoneEvent extends SSEEvent {
  final String finalResponse;

  DoneEvent({
    required this.finalResponse,
    super.timestamp,
  });

  factory DoneEvent.fromJson(Map<String, dynamic> json) {
    return DoneEvent(
      finalResponse: json['final_response'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class ErrorEvent extends SSEEvent {
  final String message;
  final String? code;

  ErrorEvent({
    required this.message,
    this.code,
    super.timestamp,
  });

  factory ErrorEvent.fromJson(Map<String, dynamic> json) {
    return ErrorEvent(
      message: json['message'],
      code: json['code'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class UnknownEventException implements Exception {
  final String eventType;
  UnknownEventException(this.eventType);

  @override
  String toString() => 'Unknown SSE event type: $eventType';
}
```

### 2.3 Create `lib/models/conversation.dart`

```dart
/// Conversation metadata from API server.
class Conversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? title;

  Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      title: json['title'],
    );
  }
}

/// Conversation with full message history.
class ConversationDetail extends Conversation {
  final List<ConversationMessage> messages;

  ConversationDetail({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.title,
    required this.messages,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      title: json['title'],
      messages: (json['messages'] as List)
          .map((msg) => ConversationMessage.fromJson(msg))
          .toList(),
    );
  }
}

class ConversationMessage {
  final String id;
  final String role;
  final dynamic content;
  final DateTime createdAt;
  final int sequenceNumber;

  ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.sequenceNumber,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      id: json['id'],
      role: json['role'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      sequenceNumber: json['sequence_number'],
    );
  }
}
```

### 2.4 Create `lib/models/geo_feature.dart`

```dart
/// Geographic feature extracted from tool results.
class GeoFeature {
  final String type;
  final double lat;
  final double lon;
  final String? label;

  GeoFeature({
    required this.type,
    required this.lat,
    required this.lon,
    this.label,
  });

  factory GeoFeature.fromJson(Map<String, dynamic> json) {
    return GeoFeature(
      type: json['type'],
      lat: json['lat'],
      lon: json['lon'],
      label: json['label'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'lat': lat,
      'lon': lon,
      'label': label,
    };
  }
}
```

---

## Step 3: Update ChatBloc

### 3.1 Simplify ChatBloc Implementation

Replace the agentic loop with API client calls:

```dart
// ABOUTME: BLoC managing chat state and API server communication.
// ABOUTME: Consumes SSE streams from API server for real-time updates.

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import '../services/api_client.dart';
import '../models/sse_event.dart';
import '../models/command_result.dart';
import '../models/message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiClient apiClient;
  final Logger logger;
  String? currentConversationId;

  ChatBloc({
    required this.apiClient,
    Logger? logger,
  })  : logger = logger ?? Logger(),
        super(ChatInitial()) {
    on<SendCommand>(_onSendCommand);
    on<CreateConversation>(_onCreateConversation);
    on<LoadConversation>(_onLoadConversation);
  }

  Future<void> _onCreateConversation(
    CreateConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final conversation = await apiClient.createConversation(
        title: event.title,
      );
      currentConversationId = conversation.id;
      logger.i('Created conversation: ${conversation.id}');

      emit(ChatReady(conversationId: conversation.id));
    } catch (e) {
      logger.e('Failed to create conversation: $e');
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onLoadConversation(
    LoadConversation event,
    Emitter<ChatState> emit,
  ) async {
    try {
      emit(ChatLoading());

      final conversation = await apiClient.getConversation(event.conversationId);
      currentConversationId = event.conversationId;

      // Convert stored messages to UI messages
      final messages = conversation.messages.map((msg) {
        return Message(
          role: msg.role,
          content: msg.content.toString(),
          timestamp: msg.createdAt,
        );
      }).toList();

      emit(ChatLoaded(
        conversationId: conversation.id,
        messages: messages,
      ));
    } catch (e) {
      logger.e('Failed to load conversation: $e');
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendCommand(
    SendCommand event,
    Emitter<ChatState> emit,
  ) async {
    // Ensure we have a conversation
    if (currentConversationId == null) {
      try {
        final conversation = await apiClient.createConversation();
        currentConversationId = conversation.id;
      } catch (e) {
        emit(ChatError('Failed to create conversation: $e'));
        return;
      }
    }

    // Add user message
    final userMessage = Message(
      role: 'user',
      content: event.command,
      timestamp: DateTime.now(),
    );

    final currentMessages = state is ChatLoaded
        ? List<Message>.from((state as ChatLoaded).messages)
        : <Message>[];
    currentMessages.add(userMessage);

    emit(ChatLoaded(
      conversationId: currentConversationId!,
      messages: currentMessages,
    ));

    // Track SSE events for result
    final llmHistory = <Map<String, dynamic>>[];
    final geoFeatures = <GeoFeature>[];
    String? finalResponse;

    try {
      // Stream events from API server
      final eventStream = apiClient.sendMessage(
        conversationId: currentConversationId!,
        message: event.command,
      );

      await for (final sseEvent in eventStream) {
        if (sseEvent is ToolCallEvent) {
          llmHistory.add({
            'type': 'tool_call',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'tool_name': sseEvent.toolName,
            'arguments': sseEvent.arguments,
          });

          // Emit intermediate state with loading indicator
          emit(ChatLoaded(
            conversationId: currentConversationId!,
            messages: currentMessages,
            isProcessing: true,
            currentToolCall: sseEvent.toolName,
          ));
        } else if (sseEvent is ToolResultEvent) {
          llmHistory.add({
            'type': 'tool_result',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'tool_name': sseEvent.toolName,
            'result': sseEvent.result,
          });
        } else if (sseEvent is ToolErrorEvent) {
          llmHistory.add({
            'type': 'tool_error',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'tool_name': sseEvent.toolName,
            'error': sseEvent.error,
          });
        } else if (sseEvent is LLMResponseEvent) {
          llmHistory.add({
            'type': 'llm_response',
            'timestamp': sseEvent.timestamp.toIso8601String(),
            'content': sseEvent.content,
            'stop_reason': sseEvent.stopReason,
          });
        } else if (sseEvent is GeoFeatureEvent) {
          geoFeatures.add(sseEvent.feature);
        } else if (sseEvent is DoneEvent) {
          finalResponse = sseEvent.finalResponse;
        } else if (sseEvent is ErrorEvent) {
          throw Exception(sseEvent.message);
        }
      }

      // Add assistant response
      final assistantMessage = Message(
        role: 'assistant',
        content: finalResponse ?? 'No response',
        timestamp: DateTime.now(),
      );
      currentMessages.add(assistantMessage);

      // Create result
      final result = CommandResult(
        command: event.command,
        response: finalResponse ?? 'No response',
        llmHistory: llmHistory,
        timestamp: DateTime.now(),
        geoFeatures: geoFeatures,
      );

      emit(ChatLoaded(
        conversationId: currentConversationId!,
        messages: currentMessages,
        latestResult: result,
      ));
    } catch (e) {
      logger.e('Error during command execution: $e');
      emit(ChatError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    apiClient.dispose();
    return super.close();
  }
}
```

### 3.2 Add New Chat Events

Update `lib/bloc/chat_event.dart`:

```dart
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
```

### 3.3 Update Chat States

Update `lib/bloc/chat_state.dart`:

```dart
abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatReady extends ChatState {
  final String conversationId;
  ChatReady({required this.conversationId});
}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final String conversationId;
  final List<Message> messages;
  final CommandResult? latestResult;
  final bool isProcessing;
  final String? currentToolCall;

  ChatLoaded({
    required this.conversationId,
    required this.messages,
    this.latestResult,
    this.isProcessing = false,
    this.currentToolCall,
  });
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}
```

---

## Step 4: Update Configuration

### 4.1 Update `.env` File

Remove Anthropic API key, add API server URL:

```
# API Server (local development)
API_SERVER_URL=http://localhost:3001

# For production/docker:
# API_SERVER_URL=http://api_server:3001
```

### 4.2 Update Environment Loading

Update `lib/main.dart` to load new configuration:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/api_client.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/map_bloc.dart';
import 'widgets/home_page.dart';

void main() async {
  await dotenv.load(fileName: '.env');

  final apiClient = ApiClient(
    baseUrl: dotenv.env['API_SERVER_URL'] ?? 'http://localhost:3001',
  );

  runApp(MyApp(apiClient: apiClient));
}

class MyApp extends StatelessWidget {
  final ApiClient apiClient;

  const MyApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ChatBloc(apiClient: apiClient)
            ..add(CreateConversation()),
        ),
        BlocProvider(
          create: (context) => MapBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Magma Soup',
        theme: ThemeData.light(),
        home: const HomePage(),
      ),
    );
  }
}
```

---

## Step 5: Remove Old Services

### 5.1 Delete Files

Remove these files completely:

- `lib/services/anthropic_service.dart`
- `lib/services/mcp_service.dart`
- `lib/services/gis_prompt_builder.dart` (logic now in API server)
- `lib/services/geo_feature_extractor.dart` (logic now in API server)

### 5.2 Update pubspec.yaml

Remove any Anthropic-specific dependencies (none currently, but verify).

The `http` package should remain for API client communication.

---

## Step 6: Add Conversation Management UI (Optional Enhancement)

### 6.1 Create Conversation List Widget

`lib/widgets/conversation/conversation_list.dart`:

```dart
// ABOUTME: Widget displaying a list of previous conversations.
// ABOUTME: Allows user to select and load conversation history.

import 'package:flutter/material.dart';
import '../../models/conversation.dart';
import '../../services/api_client.dart';

class ConversationList extends StatelessWidget {
  final ApiClient apiClient;
  final Function(String) onConversationSelected;

  const ConversationList({
    super.key,
    required this.apiClient,
    required this.onConversationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Conversation>>(
      future: apiClient.listConversations(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final conversations = snapshot.data ?? [];

        if (conversations.isEmpty) {
          return const Center(child: Text('No conversations yet'));
        }

        return ListView.builder(
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return ListTile(
              title: Text(conversation.title ?? 'Untitled'),
              subtitle: Text(
                'Updated: ${conversation.updatedAt.toLocal()}',
              ),
              onTap: () => onConversationSelected(conversation.id),
            );
          },
        );
      },
    );
  }
}
```

### 6.2 Add Conversation Selector to UI

Update main UI to include conversation switcher in app bar or drawer.

---

## Step 7: Testing

### 7.1 Integration Testing Plan

**Prerequisites:**
- API server running on `localhost:3001`
- MCP server running on `localhost:3000`
- PostGIS database accessible

**Test Scenarios:**

1. **New Conversation**
   - Launch app
   - Verify new conversation auto-created
   - Send message
   - Verify SSE stream displays tool calls in real-time
   - Verify final response appears
   - Verify map updates with geo features

2. **Tool Execution Progress**
   - Send command requiring multiple tools (e.g., "distance between SF and LA")
   - Verify loading indicator shows during tool execution
   - Verify tool names displayed (e.g., "Calling geocode_address...")
   - Verify results pane shows LLM history

3. **Error Handling**
   - Stop API server
   - Send message
   - Verify graceful error message
   - Restart API server
   - Verify app recovers

4. **Conversation Persistence**
   - Send several messages
   - Note conversation ID
   - Restart app
   - Load conversation by ID
   - Verify all messages restored

5. **Map Integration**
   - Send command with geographic results
   - Verify markers appear on map
   - Verify marker labels correct

### 7.2 Manual Testing Checklist

- [ ] App launches without errors
- [ ] No Anthropic API key required
- [ ] Messages sent successfully
- [ ] SSE events received in order
- [ ] Loading states display correctly
- [ ] Tool execution progress visible
- [ ] Final responses appear
- [ ] LLM history displayed in results pane
- [ ] Map updates with geo features
- [ ] Error messages clear and actionable
- [ ] Network failures handled gracefully
- [ ] Conversation list loads (if implemented)
- [ ] Previous conversations loadable (if implemented)

### 7.3 Verification Commands

**Check API server health:**
```bash
curl http://localhost:3001/health
```

**Manually test SSE endpoint:**
```bash
curl -N -X POST http://localhost:3001/conversations/test-id/messages \
  -H "Content-Type: application/json" \
  -d '{"message":"What is the distance between New York and Boston?"}'
```

---

## Step 8: Update Documentation

### 8.1 Update CLAUDE.md

Update architecture section to reflect new client-server model:

```markdown
## Architecture

### System Components

- **Flutter Desktop App**: Pure UI client, consumes SSE streams from API server
- **API Server** (TypeScript/Express): Orchestrates LLM interactions, executes agentic loop
- **MCP Server** (TypeScript): Provides GIS tools (geocoding, distance calculation, etc.)
- **PostGIS Database**: Stores conversation history and geographic features

### Communication Flow

1. User enters command in Flutter app
2. Flutter sends command to API server via HTTP POST
3. API server executes agentic loop:
   - Calls Anthropic API with available tools
   - Executes tools via MCP server
   - Streams progress via SSE
4. Flutter consumes SSE stream and updates UI in real-time
5. Final response and geo features displayed

### Security

- No API keys in Flutter client
- Anthropic API key only in API server (server-side)
- API server can add authentication/authorization layer
```

### 8.2 Update README.md

Add setup instructions for API server:

```markdown
## Running the Application

### Prerequisites

- Flutter SDK (3.5.4+)
- Docker and Docker Compose
- Anthropic API key

### Setup

1. **Start backend services:**
   ```bash
   # Copy environment template
   cp .env.example .env

   # Add your Anthropic API key to .env
   echo "ANTHROPIC_API_KEY=sk-ant-..." >> .env

   # Start services (PostGIS, MCP server, API server)
   docker-compose up
   ```

2. **Run Flutter app:**
   ```bash
   cd flutter_client
   flutter run
   ```

The Flutter app will connect to the API server at `http://localhost:3001`.
```

---

## Step 9: Deployment Considerations

### 9.1 Docker Setup for Flutter (Optional)

For fully containerized deployment, consider creating a Flutter web build:

**`flutter_client/Dockerfile`** (for web deployment):
```dockerfile
FROM debian:latest AS build-env

# Install Flutter dependencies
RUN apt-get update
RUN apt-get install -y curl git wget unzip libgconf-2-4 glib-2.0 libstdc++6 libglu1-mesa
RUN apt-get clean

# Clone Flutter repository
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter

# Set Flutter path
ENV PATH="/usr/local/flutter/bin:${PATH}"

# Enable Flutter web
RUN flutter channel stable
RUN flutter upgrade
RUN flutter config --enable-web

# Copy files
WORKDIR /app
COPY . .

# Build web app
RUN flutter build web

# Nginx stage
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
```

**Update `docker-compose.yml`:**
```yaml
  flutter_web:
    build:
      context: ./flutter_client
      dockerfile: Dockerfile
    container_name: magma-soup-flutter-web
    ports:
      - "8080:80"
    environment:
      - API_SERVER_URL=http://localhost:3001
```

### 9.2 Production Environment Variables

For production deployment:

```env
# Production API Server URL
API_SERVER_URL=https://api.magmasoup.example.com

# For local development
# API_SERVER_URL=http://localhost:3001

# For Docker Compose
# API_SERVER_URL=http://api_server:3001
```

### 9.3 CORS Configuration

Ensure API server allows Flutter client origin:

**In `api_server/src/index.ts`:**
```typescript
app.use(cors({
  origin: [
    'http://localhost:*',      // Flutter desktop dev
    'http://127.0.0.1:*',      // Flutter desktop dev
    'https://app.magmasoup.example.com',  // Production web app
  ],
  credentials: true,
}));
```

---

## Success Criteria

Phase 4 is complete when:

### Core Functionality
1. ✅ Flutter app launches without Anthropic API key
2. ✅ Messages sent to API server successfully
3. ✅ SSE events consumed and displayed in real-time
4. ✅ Tool execution progress visible to user
5. ✅ Final responses displayed correctly
6. ✅ LLM history shown in results pane
7. ✅ Map updates with geographic features
8. ✅ Error handling graceful and user-friendly

### Code Quality
9. ✅ No references to `AnthropicService` in codebase
10. ✅ No references to `MCPService` in codebase
11. ✅ No direct MCP server calls from Flutter
12. ✅ No Anthropic API key in `.env` or code
13. ✅ Clean separation: Flutter = UI, API server = orchestration

### Testing
14. ✅ Manual testing checklist completed
15. ✅ All test scenarios pass
16. ✅ App works with dockerized backend
17. ✅ Network error scenarios handled

### Documentation
18. ✅ README updated with new architecture
19. ✅ CLAUDE.md reflects current system
20. ✅ Setup instructions accurate and complete

---

## Rollback Plan

If Phase 4 encounters blocking issues:

### Quick Rollback Steps

1. **Revert Flutter client changes:**
   ```bash
   git checkout HEAD~1 flutter_client/
   ```

2. **Keep API server changes** (Phase 1-3) - they're self-contained

3. **Flutter continues to work in old mode** until issues resolved

### Partial Migration Option

If SSE streaming proves problematic, consider:

1. **Simple HTTP polling** as fallback
2. **WebSocket upgrade** instead of SSE
3. **Chunked transfer encoding** instead of SSE

---

## Timeline Estimate

### Development Phases

- **Step 1-2** (API Client + Models): 3-4 hours
- **Step 3** (ChatBloc Refactor): 3-4 hours
- **Step 4-5** (Config + Cleanup): 1-2 hours
- **Step 6** (Conversation UI): 2-3 hours (optional)
- **Step 7** (Testing): 3-4 hours
- **Step 8-9** (Documentation + Deployment): 1-2 hours

**Total Core**: 10-14 hours
**Total with Conversation UI**: 12-17 hours

---

## Known Issues and Considerations

### 1. SSE Browser Limitations

**Issue**: Some browsers limit concurrent SSE connections (6 per domain).

**Impact**: Minimal for desktop app (uses native HTTP client, not browser).

**Mitigation**: If moving to Flutter web, implement connection pooling or WebSocket upgrade.

### 2. Reconnection Strategy

**Issue**: Network interruptions break SSE streams.

**Mitigation**: Implement auto-retry with exponential backoff in `ApiClient`:

```dart
Stream<SSEEvent> sendMessage({
  required String conversationId,
  required String message,
  int maxRetries = 3,
}) async* {
  int attempt = 0;

  while (attempt < maxRetries) {
    try {
      // ... existing streaming logic ...
      break;  // Success
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) rethrow;
      await Future.delayed(Duration(seconds: 2 * attempt));
    }
  }
}
```

### 3. Long-Running Requests

**Issue**: Some GIS operations may take 10+ seconds.

**Mitigation**:
- Increase HTTP client timeout
- Show progress indicators
- Allow cancellation

```dart
final httpClient = http.Client();
// Note: http package doesn't have explicit timeout on Client level
// Set timeout at request level or use timeout wrapper
```

### 4. Message Size Limits

**Issue**: Very long tool results may exceed SSE event size limits.

**Mitigation**: API server should chunk large results or provide result IDs with separate fetch endpoint.

---

## Future Enhancements (Post-Phase 4)

### Short-term (Next Sprint)

1. **Message Editing** - Edit and resubmit previous messages
2. **Conversation Titles** - Auto-generate titles from first message
3. **Search** - Search within conversation history
4. **Export** - Export conversations to Markdown/PDF

### Medium-term (Next Quarter)

1. **Multi-user Support** - Add authentication and user accounts
2. **Shared Conversations** - Collaborate on conversations
3. **Custom Tools** - User-defined MCP tools
4. **Offline Mode** - Cache conversations for offline viewing

### Long-term (Roadmap)

1. **Mobile App** - iOS/Android versions
2. **Voice Input** - Speech-to-text for commands
3. **Plugins** - Extensible plugin system
4. **Analytics** - Usage statistics and insights

---

## Files Created/Modified

### New Files

- `lib/services/api_client.dart`
- `lib/models/sse_event.dart`
- `lib/models/conversation.dart`
- `lib/models/geo_feature.dart`
- `lib/widgets/conversation/conversation_list.dart` (optional)

### Modified Files

- `lib/main.dart` - Initialize `ApiClient`, update BLoC providers
- `lib/bloc/chat_bloc.dart` - Replace agentic loop with API client calls
- `lib/bloc/chat_event.dart` - Add conversation management events
- `lib/bloc/chat_state.dart` - Add conversation states
- `flutter_client/.env` - Remove Anthropic key, add API server URL
- `flutter_client/pubspec.yaml` - Verify dependencies (no changes needed)

### Deleted Files

- `lib/services/anthropic_service.dart`
- `lib/services/mcp_service.dart`
- `lib/services/gis_prompt_builder.dart`
- `lib/services/geo_feature_extractor.dart`

---

## Next Steps After Phase 4

Once Phase 4 is complete, the architecture migration is **DONE**. The system will have:

1. ✅ **Secure architecture** - No API keys in client
2. ✅ **Scalable backend** - API server can handle multiple clients
3. ✅ **Clean separation** - UI, orchestration, tools, data all independent
4. ✅ **Persistent storage** - Conversation history preserved
5. ✅ **Containerized deployment** - docker-compose for full stack
6. ✅ **Streaming UX** - Real-time progress updates

**Optional follow-ups:**
- Performance optimization (caching, connection pooling)
- Security hardening (authentication, rate limiting)
- Feature additions (search, export, sharing)
- Mobile apps (iOS/Android Flutter builds)
- Analytics and monitoring

---

## Questions to Resolve Before Starting

1. **Conversation auto-creation**: Should app auto-create a conversation on launch, or require explicit user action?
   - **Recommendation**: Auto-create on first message send (better UX)

2. **Conversation list UI**: Include in Phase 4 or defer?
   - **Recommendation**: Defer to post-Phase 4 enhancement (keep scope manageable)

3. **Error retry logic**: Auto-retry on network failures or require manual retry?
   - **Recommendation**: Auto-retry with exponential backoff, max 3 attempts

4. **Loading indicators**: Show during tool execution? Where?
   - **Recommendation**: Yes, show tool name in chat pane ("Executing: geocode_address...")

5. **Message history limit**: Load all messages or paginate?
   - **Recommendation**: Load all for now (defer pagination until performance issues)

---

## Appendix: SSE Format Example

For reference, here's what the SSE stream looks like:

```
event: tool_call
data: {"tool_name":"geocode_address","arguments":{"address":"San Francisco, CA"},"tool_use_id":"toolu_123","timestamp":"2025-01-15T10:30:00Z"}

event: tool_result
data: {"tool_name":"geocode_address","result":"{\"lat\":37.7749,\"lon\":-122.4194}","tool_use_id":"toolu_123","timestamp":"2025-01-15T10:30:01Z"}

event: tool_call
data: {"tool_name":"geocode_address","arguments":{"address":"Los Angeles, CA"},"tool_use_id":"toolu_124","timestamp":"2025-01-15T10:30:02Z"}

event: tool_result
data: {"tool_name":"geocode_address","result":"{\"lat\":34.0522,\"lon\":-118.2437}","tool_use_id":"toolu_124","timestamp":"2025-01-15T10:30:03Z"}

event: tool_call
data: {"tool_name":"calculate_distance","arguments":{"lat1":37.7749,"lon1":-122.4194,"lat2":34.0522,"lon2":-118.2437},"tool_use_id":"toolu_125","timestamp":"2025-01-15T10:30:04Z"}

event: tool_result
data: {"tool_name":"calculate_distance","result":"559.12 km","tool_use_id":"toolu_125","timestamp":"2025-01-15T10:30:05Z"}

event: geo_feature
data: {"feature":{"type":"marker","lat":37.7749,"lon":-122.4194,"label":"San Francisco, CA"},"timestamp":"2025-01-15T10:30:05Z"}

event: geo_feature
data: {"feature":{"type":"marker","lat":34.0522,"lon":-118.2437,"label":"Los Angeles, CA"},"timestamp":"2025-01-15T10:30:05Z"}

event: llm_response
data: {"content":"The distance between San Francisco and Los Angeles is approximately 559 kilometers.","stop_reason":"end_turn","timestamp":"2025-01-15T10:30:06Z"}

event: done
data: {"final_response":"The distance between San Francisco and Los Angeles is approximately 559 kilometers.","timestamp":"2025-01-15T10:30:06Z"}
```

---

## Conclusion

Phase 4 completes the architecture migration by removing all Anthropic API dependencies from the Flutter client and establishing it as a pure presentation layer. The client now communicates exclusively with the API server via SSE streaming, providing a responsive UX while maintaining security and scalability.

The completed architecture follows a clean separation of concerns:
- **Flutter**: User interface and map visualization
- **API Server**: Agentic loop orchestration and LLM interaction
- **MCP Server**: GIS tool execution
- **PostGIS**: Data persistence

This architecture enables future enhancements like multi-user support, authentication, and mobile clients without requiring changes to the core agentic loop logic.
