#!/usr/bin/env bash
# ============================================================
# opencode-bridge.sh — 神託をOpenCode APIへ橋渡しする神具
#
# 用法:
#   ./opencode-bridge.sh --task-file <path> [--dry-run] [--timeout <sec>]
#
# 役割:
#   1. タスクYAMLを読み取り、OpenCodeプロンプトに変換
#   2. opencode run で非対話実行
#   3. 結果を queue/reports/<task_id>_done.yaml に報告
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- エージェント情報マッピング ----------------------------------
declare -A AGENT_MODEL=(
  ["pm"]="opencode-go/deepseek-v4-pro"
  ["dev"]="opencode-go/kimi-k2.6"
  ["ux"]="opencode-go/qwen3.6-plus"
  ["qa"]="opencode-go/deepseek-v4-flash"
)

declare -A AGENT_ID=(
  ["pm"]="omoiKane"
  ["dev"]="amenoMahitotsu"
  ["ux"]="amenoUzume"
  ["qa"]="tsukuyomi"
)

declare -A GOD_ROLES=(
  ["pm"]="汝は思兼神（オモイカネ）。知恵を司り、神想（仕様）を紡ぐプロダクトマネージャーである。
与えられたタスクに基づき、神想（仕様書）の策定・優先順位付け・ロードマップの立案を行え。
技術実装の詳細には立ち入らず、PMとしての判断を奏上せよ。"

  ["dev"]="汝は天目一箇神（アメノマヒトツ）。鍛冶を司り、Flutter/Dartで現世を具現化する開発神である。
与えられたタスクに基づき、コードの実装・修正・リファクタリングを行え。
既存コードの慣習に従い、試練（テスト）を先に書く鍛冶の儀式を守れ。"

  ["ux"]="汝は天宇受賣命（アメノウズメ）。神楽を舞い、ユーザー体験を設計するUX神である。
与えられたタスクに基づき、UI/UXの監査・改善提案・ゲーミフィケーション設計を行え。
楽しさと使いやすさを最優先に、心が動く体験を提案せよ。"

  ["qa"]="汝は月読命（ツクヨミ）。月の光で禍津（バグ）を照らすQA神である。
与えられたタスクに基づき、コードベースの精査・テスト設計・バグ発見を行え。
見つけた問題はすべて報告し、改善提案を添えよ。"
)

# --- 引数解析 -------------------------------------------------
TASK_FILE=""
DRY_RUN=0
TIMEOUT=600

usage() {
    cat <<'EOF'
用法: opencode-bridge.sh --task-file <path> [--dry-run] [--timeout <sec>]

  タスクYAMLを読み取り、OpenCode で非対話実行し、結果を報告する。

  --task-file   タスク定義YAMLファイルのパス（必須）
  --dry-run     プロンプト表示のみ。OpenCodeは実行しない
  --timeout     実行タイムアウト秒（デフォルト: 600）
  --help        この助言を表示
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --task-file) TASK_FILE="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --timeout)   TIMEOUT="$2"; shift 2 ;;
        --help)      usage ;;
        *) echo "【禍津】未知の引数: $1"; usage ;;
    esac
done

if [[ -z "$TASK_FILE" ]]; then
    echo "【禍津】--task-file は必須なり。" >&2
    exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
    echo "【禍津】タスクファイルが存在せぬ: $TASK_FILE" >&2
    exit 1
fi

# --- YAMLパース（簡易）-----------------------------------------
# 簡易YAMLパーサー: シェルで安全にフィールドを抽出
parse_yaml_field() {
    local file="$1" field="$2"
    grep "^$field:" "$file" | head -1 | sed "s/^$field:[[:space:]]*//" | sed 's/^"//;s/"$//'
}

TASK_ID="$(parse_yaml_field "$TASK_FILE" "task_id")"
TITLE="$(parse_yaml_field "$TASK_FILE" "title")"
ASSIGNED_TO="$(parse_yaml_field "$TASK_FILE" "assigned_to")"
PRIORITY="$(parse_yaml_field "$TASK_FILE" "priority")"

# context フィールド（複数行インデント対応）
CONTEXT=$(awk '/^context:/{in_context=1; next} in_context && /^[a-z]/ && !/^[[:space:]]/{exit} in_context{print}' "$TASK_FILE" \
  | sed 's/^[[:space:]]*//' || true)

if [[ -z "$CONTEXT" ]]; then
    CONTEXT=$(parse_yaml_field "$TASK_FILE" "context")
fi

# artifacts フィールド
ARTIFACTS=$(awk '/^artifacts:/{in_art=1; next} in_art && /^[a-z]/ && !/^[[:space:]]/{exit} in_art{print}' "$TASK_FILE" \
  | sed 's/^[[:space:]]*//' || true)

# --- バリデーション ---------------------------------------------
if [[ -z "$TASK_ID" ]] || [[ -z "$ASSIGNED_TO" ]]; then
    echo "【禍津】タスクYAMLに task_id または assigned_to が記されていない。" >&2
    exit 1
fi

if [[ -z "${AGENT_MODEL[$ASSIGNED_TO]:-}" ]]; then
    echo "【禍津】未知のassigned_to: $ASSIGNED_TO (pm/dev/ux/qa を指定せよ)" >&2
    exit 1
fi

MODEL="${AGENT_MODEL[$ASSIGNED_TO]}"
AGENT_OPTS="--agent ${AGENT_ID[$ASSIGNED_TO]} --model $MODEL"
ROLE_PROMPT="${GOD_ROLES[$ASSIGNED_TO]}"

# --- プロンプト生成 ---------------------------------------------
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

PROMPT="${ROLE_PROMPT}

## 創造主様よりの神託
**タスクID**: ${TASK_ID}
**タイトル**: ${TITLE}
**優先度**: ${PRIORITY}
**期限**: 直ちに実行せよ

### 指示内容
${CONTEXT}"

if [[ -n "$ARTIFACTS" ]]; then
    PROMPT+="

### 関連資料
${ARTIFACTS}"
fi

PROMPT+="

### 奏上の作法
- 完了したら、何を行ったかを簡潔に報告せよ
- 変更したファイルとその概要を明示せよ
- 問題があればそれも報告せよ"

# --- ドライランモード --------------------------------------------
if [[ $DRY_RUN -eq 1 ]]; then
    echo "=== DRY RUN: 以下のプロンプトを実行する ==="
    echo "宛先: $ASSIGNED_TO (${AGENT_ID[$ASSIGNED_TO]})"
    echo "モデル: $MODEL"
    echo "タイムアウト: ${TIMEOUT}秒"
    echo "---"
    echo "$PROMPT"
    echo "---"
    exit 0
fi

# --- OpenCode 実行 ----------------------------------------------
if ! command -v opencode &>/dev/null; then
    echo "【禍津】opencode が見つからぬ。まずは OpenCode を導入せよ。" >&2
    echo "        curl -fsSL https://opencode.ai/install | bash" >&2
    exit 1
fi

echo "【神託執行】${TASK_ID} → ${ASSIGNED_TO} (${AGENT_ID[$ASSIGNED_TO]}) via $MODEL"
echo ""

REPORTS_DIR="$PROJECT_DIR/queue/reports"
mkdir -p "$REPORTS_DIR"

RESULT=0
TEMP_LOG=$(mktemp)

# opencode run で非対話実行（プロンプトは一時ファイル経由）
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

cd "$PROJECT_DIR"

if timeout "$TIMEOUT" opencode run \
    $AGENT_OPTS \
    --dangerously-skip-permissions \
    "$(cat "$PROMPT_FILE")" > "$TEMP_LOG" 2>&1; then
    RESULT=0
    STATUS="completed"
else
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 124 ]]; then
        RESULT=1
        STATUS="failed"
        echo "【禍津】タイムアウト（${TIMEOUT}秒）" >> "$TEMP_LOG"
    else
        RESULT=1
        STATUS="failed"
    fi
fi

rm -f "$PROMPT_FILE"

# --- 結果の抽出 ------------------------------------------------
SUMMARY=$(tail -50 "$TEMP_LOG" | head -40)

# 完了報告YAMLを生成
REPORT_FILE="$REPORTS_DIR/${TASK_ID}_done.yaml"
COMPLETED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$REPORT_FILE" << YAML
task_id: "${TASK_ID}"
status: "${STATUS}"
completed_at: "${COMPLETED_AT}"
assigned_to: "${ASSIGNED_TO}"
model: "${MODEL}"
summary: |
$(echo "$SUMMARY" | sed 's/^/  /')
artifacts:
  raw_log: "$TEMP_LOG"
YAML

# --- 出力 -------------------------------------------------------
if [[ $RESULT -eq 0 ]]; then
    echo ""
    echo "【奏上】神託 ${TASK_ID} は成就せり。"
else
    echo ""
    echo "【禍津】神託 ${TASK_ID} は失敗に終わりたもうた。"
fi

echo "報告: $REPORT_FILE"
echo ""

# ログファイルを標準出力にも出す（末尾のみ）
if [[ -s "$TEMP_LOG" ]]; then
    echo "--- OpenCode 出力（末尾）---"
    tail -40 "$TEMP_LOG"
    echo "--- 以上 ---"
fi
