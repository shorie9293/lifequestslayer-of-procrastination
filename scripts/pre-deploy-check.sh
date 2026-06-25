#!/bin/bash
# ⛩️ Pre-deploy check — デプロイ前に CI 同等の全チェックをローカル実行
# rpg-task 専用：CI の 3-shard テスト構造をローカルで再現
# 八百万の掟：デプロイ前には必ずこのスクリプトを通せ
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⛩️  Pre-deploy check: rpg-task"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- Step 1: flutter pub get ---
echo ""
echo "[1/5] 📦 flutter pub get..."
flutter pub get
echo "✅ pub get OK"

# --- Step 2: flutter analyze ---
echo ""
echo "[2/5] 🔍 flutter analyze --no-fatal-infos..."
flutter analyze --no-fatal-infos
echo "✅ analyze OK (no warnings or errors)"

# --- Step 3: Test shard 1/3 (domain, guild, kozuchi, player, shared) ---
echo ""
echo "[3/5] 🧪 test shard 1/3..."
flutter test --no-pub -j 2 \
  test/domain/ \
  test/features/guild/ \
  test/features/kozuchi/ \
  test/features/player/ \
  test/features/shared/
echo "✅ shard 1/3 passed"

# --- Step 4: Test shard 2/3 (battle, temple, character_customization, etc.) ---
echo ""
echo "[4/5] 🧪 test shard 2/3..."
flutter test --no-pub -j 1 \
  test/features/battle/domain/ \
  test/features/battle/presentation/ \
  test/features/battle/viewmodels/ \
  test/features/battle/battle_report_dialog_samurai_test.dart \
  test/features/temple/ \
  test/features/character_customization/ \
  test/features/crossapp/ \
  test/features/overview/ \
  test/features/town/
echo "✅ shard 2/3 passed"

# --- Step 5: Test shard 3/3 (root-level tests + individual files) ---
echo ""
echo "[5/5] 🧪 test shard 3/3..."
flutter test --no-pub -j 1 \
  test/game_view_model_test.dart \
  test/player_test.dart \
  test/task_test.dart \
  test/reflection_test.dart \
  test/battle_state_test.dart \
  test/date_utils_test.dart \
  test/debug_overdue_test.dart \
  test/difficulty_estimator_test.dart \
  test/di_injection_test.dart \
  test/fatigue_service_test.dart \
  test/game_themes_test.dart \
  test/help_dialog_test.dart \
  test/iap_service_test.dart \
  test/m12_cancel_persistence_test.dart \
  test/notification_service_test.dart \
  test/quiz_service_test.dart \
  test/rank_colors_test.dart \
  test/settings_repository_test.dart \
  test/streak_service_test.dart \
  test/title_definition_test.dart \
  test/title_service_test.dart \
  test/widget_test.dart
echo "✅ shard 3/3 passed"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Pre-deploy check PASSED — safe to deploy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
