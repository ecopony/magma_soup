# Magma Soup

A Flutter desktop application featuring a split-pane interface for command execution and results visualization.

## Features

- **Two-pane layout**: Chat interface on the left, results display on the right
- **Command interface**: Enter and execute commands through a conversational UI
- **Real-time results**: View command outputs in a dedicated results pane
- **Solarized Light theme**: Easy-on-the-eyes color scheme throughout

## Tech Stack

- **Flutter** - Cross-platform UI framework (desktop target)
- **BLoC** - State management pattern
- **flutter_bloc** - BLoC implementation for Flutter

## Getting Started

### Prerequisites

- Flutter SDK 3.24.5 or later
- macOS (currently configured for macOS desktop)

### Installation

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Project Structure

```
lib/
  bloc/                      # BLoC state management
    chat_bloc.dart           # Chat messages and conversation flow
    chat_event.dart
    chat_state.dart
    agentic_trace_bloc.dart  # LLM execution trace (tool calls/results)
    agentic_trace_event.dart
    agentic_trace_state.dart
    map_bloc.dart            # Map visualization state
    map_event.dart
    map_state.dart
  models/                    # Data models
    message.dart
    command_result.dart
    conversation.dart
    geo_feature.dart
    sse_event.dart
  services/                  # External services
    api_client.dart          # SSE streaming from API server
  widgets/                   # UI components
    chat/                    # Chat interface
    results/                 # Results display
    map/                     # Map visualization
    llm_interaction/         # LLM trace viewer
  main.dart                  # App entry point
```

## Usage

1. Launch the application
2. Type commands in the chat interface (left pane)
3. Press Enter or click the send button
4. View results in the results pane (right pane)
