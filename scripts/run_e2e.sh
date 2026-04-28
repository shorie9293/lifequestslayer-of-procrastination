#!/usr/bin/env bash
# run_e2e.sh — E2E試練実行の儀
# 用法: ./run_e2e.sh [--headed] [--ui] [--report]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
E2E_DIR="$PROJECT_DIR/e2e"
BUILD_DIR="$PROJECT_DIR/build/web"

HEADED=""
UI_MODE=""
REPORT_ONLY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --headed) HEADED="--headed"; shift ;;
        --ui)     UI_MODE="--ui"; shift ;;
        --report) REPORT_ONLY=1; shift ;;
        *) echo "未知の引数: $1"; exit 1 ;;
    esac
done

echo "=== E2E試練の儀 ==="

# 1. 依存確認
if ! command -v npx &>/dev/null; then
    echo "【禍津】Node.js/npmが見当たらぬ。導入せよ。"
    exit 1
fi

cd "$E2E_DIR"

# 2. 依存導入
if [[ ! -d node_modules ]]; then
    echo "Playwright を導入中..."
    npm install --silent
    npx playwright install chromium --with-deps 2>/dev/null || npx playwright install chromium
fi

# 3. レポート表示のみ
if [[ -n "$REPORT_ONLY" ]]; then
    if [[ -d playwright-report ]]; then
        npx playwright show-report
    else
        echo "レポートなし。先に試練を実行せよ。"
    fi
    exit 0
fi

# 4. Flutter Webビルド
echo ""
echo "Flutter Web をビルド中..."
cd "$PROJECT_DIR"
flutter build web --quiet 2>&1 | tail -1 || {
    echo "【禍津】ビルドに失敗。flutter build web を手動で確認せよ。"
    exit 1
}
echo "ビルド完了: $BUILD_DIR"

# 5. 試練実行
echo ""
cd "$E2E_DIR"

if [[ -n "$UI_MODE" ]]; then
    echo "GUIモードで試練を実行..."
    npx playwright test --ui
elif [[ -n "$HEADED" ]]; then
    echo "ブラウザ表示モードで試練を実行..."
    npx playwright test --headed
else
    echo "ヘッドレスモードで試練を実行..."
    npx playwright test
fi

echo ""
echo "=== E2E試練 完了 ==="
