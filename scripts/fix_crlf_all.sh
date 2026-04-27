#!/usr/bin/env bash
# fix_crlf_all.sh — プロジェクト内全テキストファイルのCRLF→LF変換
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== CRLF→LF 一括変換の儀 ==="

find "$PROJECT_DIR" -type f \( \
    -name "*.dart" -o \
    -name "*.yaml" -o \
    -name "*.md" -o \
    -name "*.json" -o \
    -name "*.gradle" -o \
    -name "*.kts" -o \
    -name "*.properties" -o \
    -name "*.xml" -o \
    -name "*.sh" -o \
    -name "*.html" -o \
    -name "*.css" -o \
    -name "*.toml" -o \
    -name "*.txt" -o \
    -name "*.js" -o \
    -name "*.ts" \
\) -not -path "*.git/*" \
  -not -path "*.dart_tool/*" \
  -not -path "*build/*" \
  -not -path "*.idea/*" \
  -not -path "*node_modules/*" \
  -not -path "*.climpire/*" \
  -not -path "*.climpire-worktrees/*" \
  -not -path "*.antigravity/*" \
  -not -path "*.claude/*" \
| while read -r f; do
    if grep -q $'\r' "$f" 2>/dev/null; then
        echo "  変換: $f"
        sed -i 's/\r$//' "$f"
    fi
done

echo "=== 変換完了 ==="
echo ""
echo "残存CRLFファイル数（0であるべし）:"
find "$PROJECT_DIR" -type f \( -name "*.dart" -o -name "*.yaml" -o -name "*.md" \) \
  -not -path "*.git/*" -not -path "*.dart_tool/*" -not -path "*build/*" \
  -exec grep -l $'\r' {} \; 2>/dev/null | wc -l
