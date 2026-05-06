#!/usr/bin/env bash
#
# coverage.sh — カバレッジレポート生成スクリプト
#
# 使用方法:
#   ./scripts/coverage.sh            # LCOV + HTMLレポートを生成
#   ./scripts/coverage.sh --html     # HTMLレポートのみ生成 (genhtml必須)
#   ./scripts/coverage.sh --lcov     # LCOV情報のみ生成
#
# 必要条件:
#   - Flutter SDK
#   - lcov (HTMLレポート生成時に必要。apt: sudo apt install lcov)
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

LCOV_FILE="coverage/lcov.info"
HTML_DIR="coverage/html"

show_help() {
    echo "使用方法: $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  --html     HTMLレポートのみ生成 (genhtmlが必要)"
    echo "  --lcov     LCOVカバレッジ情報のみ生成"
    echo "  (なし)     LCOV + HTMLレポートを生成"
    echo "  --help     このヘルプを表示"
    echo ""
    echo "出力:"
    echo "  $LCOV_FILE  - LCOVカバレッジデータ"
    echo "  $HTML_DIR/  - HTMLカバレッジレポート"
}

MODE="full"

for arg in "$@"; do
    case "$arg" in
        --html) MODE="html" ;;
        --lcov) MODE="lcov" ;;
        --help) show_help; exit 0 ;;
        *) echo "不明なオプション: $arg"; show_help; exit 1 ;;
    esac
done

echo "========================================"
echo " rpg-task カバレッジレポート生成"
echo "========================================"
echo ""

# Step 1: テスト実行 + カバレッジ収集
echo "[1/3] テストを実行中 (--coverage)..."
flutter test --no-pub --coverage

if [ ! -f "$LCOV_FILE" ]; then
    echo "エラー: $LCOV_FILE が生成されませんでした。"
    exit 1
fi

echo "  ✓ LCOVデータ生成完了: $LCOV_FILE"

# Step 2: LCOVサマリー表示
echo ""
echo "[2/3] カバレッジサマリー:"

if command -v lcov &> /dev/null; then
    lcov --summary "$LCOV_FILE" 2>&1 | grep -E "lines|functions|branches" || true
else
    echo "  (lcov未インストールのためサマリーをスキップします)"
    echo "  インストール方法: sudo apt install lcov"
fi

# Step 3: HTMLレポート生成
if [ "$MODE" = "lcov" ]; then
    echo ""
    echo "LCOVファイル: $LCOV_FILE"
    echo "完了 (HTMLレポートはスキップしました)"
    exit 0
fi

echo ""
echo "[3/3] HTMLレポート生成中..."

if ! command -v genhtml &> /dev/null; then
    echo "  ✗ genhtml が見つかりません。lcov をインストールしてください:"
    echo "    sudo apt install lcov"
    echo ""
    echo "  LCOVファイルは生成済みです: $LCOV_FILE"
    exit 1
fi

rm -rf "$HTML_DIR"
mkdir -p "$(dirname "$HTML_DIR")"

genhtml "$LCOV_FILE" -o "$HTML_DIR" --quiet 2>&1

echo "  ✓ HTMLレポート生成完了: $HTML_DIR/index.html"
echo ""
echo "========================================"
echo " 完了！"
echo " HTMLレポート: file://$PROJECT_ROOT/$HTML_DIR/index.html"
echo " LCOVデータ:   $PROJECT_ROOT/$LCOV_FILE"
echo "========================================"
