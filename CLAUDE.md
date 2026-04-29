# CLAUDE.md

> **⚠️ 最重要方針書**: 本プロジェクトの改善方針は `docs/roadmap.md` に定められている。あらゆる改善作業の前に必ず `docs/roadmap.md` を参照せよ。

## Project Overview

**rpg_todo** is a Flutter-based RPG-themed task management app. Tasks are presented in a game-like "Adventurer's Guild" interface with a `GameViewModel` managing player state and task logic.

## Tech Stack

- **Framework**: Flutter (Dart SDK ^3.5.4)
- **State Management**: Provider (`provider: ^6.1.5+1`)
- **Local Storage**: Hive (`hive: ^2.2.3`, `hive_flutter: ^1.1.0`)
- **Fonts**: Google Fonts (`google_fonts: ^6.3.0`)
- **ID Generation**: UUID (`uuid: ^4.5.2`)
- **Current Version**: 1.0.4+5

## Project Structure

```
lib/
  main.dart           # App entry point
  models/             # Data models
  providers/          # Provider state classes
  repositories/       # Data access layer
  screens/            # UI screens (home, guild, main)
  utils/              # Utility functions
  viewmodels/         # ViewModels (GameViewModel, etc.)
  widgets/            # Reusable widgets (TaskCard, tutorial overlay, etc.)
assets/
  images/             # Image assets
docs/
  log/                # Development logs
```

## Common Commands

```bash
# Run the app
flutter run

# Build for Android (app bundle)
flutter build appbundle

# Build for web
flutter build web

# Run tests
flutter test

# Analyze code
flutter analyze

# Get dependencies
flutter pub get
```

## Architecture Notes

- Follows MVVM pattern: `screens/` → `viewmodels/` → `repositories/` → `models/`
- State is managed via `Provider` and `ChangeNotifier`
- Hive is used for persistent local storage
- RPG-themed UI: tasks appear as guild quests, players gain XP on completion
