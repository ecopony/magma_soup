# Magma Soup

A Flutter desktop application with a two-pane interface for command execution.

## Architecture

- **Flutter**: Desktop app (macOS support)
- **State Management**: BLoC pattern using flutter_bloc
- **Theme**: Solarized Light color scheme

## Project Structure

- `lib/models/` - Data models (Message, CommandResult)
- `lib/bloc/` - BLoC implementation (ChatBloc, events, states)
- `lib/widgets/` - UI components (ChatPane, ResultsPane)

## UI Layout

Two-pane split view:
- **Left pane**: Chat interface for entering commands
- **Right pane**: Display area for command results

## Running

```bash
flutter run
```
