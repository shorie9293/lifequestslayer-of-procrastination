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
- **Monorepo Packages**: takamagahara_core, takamagahara_ui, takamagahara_ai (`../../packages/`)
- **Current Version**: 1.4.26+84

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

# Analyze code (CI runs with --no-fatal-infos — warnings = CI failure)
flutter analyze --no-fatal-infos

# Get dependencies
flutter pub get
```

## Architecture Notes

- Follows MVVM pattern: `screens/` → `viewmodels/` → `repositories/` → `models/`
- State is managed via `Provider` and `ChangeNotifier`
- Hive is used for persistent local storage
- RPG-themed UI: tasks appear as guild quests, players gain XP on completion

## ⛩️ Push Gate

**Pre-push hook** at `.git/hooks/pre-push` runs `flutter analyze --no-fatal-infos` before every push.
- Warnings (not just errors) cause exit code 1 = push REJECTED.
- This mirrors the CI check exactly — no more 4-consecutive CI failures from missed warnings.
- Info-level issues (deprecated API, unused print, etc.) are suppressed by `--no-fatal-infos` and won't block.

## 🚀 Pre-Deploy Check

Before deploying, run the full CI simulation:
```bash
bash scripts/pre-deploy-check.sh
```
This runs: `flutter pub get` → `flutter analyze --no-fatal-infos` → 3-shard `flutter test` (mirrors CI exactly).
All must pass before deployment. Shard 3 uses `-j 1` (serial) to avoid Hive state contamination flakes.

## CI/CD

- **CI**: `.github/workflows/flutter-ci.yml` — runs on push/PR to main
  - Setup monorepo packages → flutter pub get → analyze → 3-shard test
  - Shard 1: domain, guild, kozuchi, player, shared (`-j 2`)
  - Shard 2: battle, temple, character_customization, crossapp, overview, town (`-j 1`)
  - Shard 3: root-level tests, individual files (`-j 1`, `continue-on-error: true` for flakes)
- **Deploy**: `.github/workflows/deploy.yml` — triggers on `pubspec.yaml` change on main
  - Builds AAB → deploys to Google Play via fastlane
