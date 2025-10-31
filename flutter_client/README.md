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
  bloc/             # BLoC state management
    chat_bloc.dart
    chat_event.dart
    chat_state.dart
  models/           # Data models
    message.dart
    command_result.dart
  widgets/          # UI components
    chat_pane.dart
    results_pane.dart
  main.dart         # App entry point
```

## Usage

1. Launch the application
2. Type commands in the chat interface (left pane)
3. Press Enter or click the send button
4. View results in the results pane (right pane)
