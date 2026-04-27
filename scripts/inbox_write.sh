#!/usr/bin/env bash
# ============================================================
# inbox_write.sh — 神々の書簡送付の儀
#
# 用法:
#   ./inbox_write.sh --agent <pm|dev|ux|qa> --file <task_yaml>
#                    [--task-id <id>] [--from <sender>]
#
# 排他ロック(flock)を用いて、指定された神の受信トレイ
# (queue/inbox/<agent>.yaml) へ安全に書簡を追記する。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUEUE_DIR="$PROJECT_DIR/queue"
INBOX_DIR="$QUEUE_DIR/inbox"
TASKS_DIR="$QUEUE_DIR/tasks"

VALID_AGENTS=("pm" "dev" "ux" "qa")

# --- 引数解析 -------------------------------------------------
AGENT=""
TASK_FILE=""
TASK_ID=""
FROM="八百万システム"

usage() {
    cat <<'EOF'
用法: inbox_write.sh --agent <pm|dev|ux|qa> --file <task_yaml>
                      [--task-id <id>] [--from <sender>]

  他の神の受信トレイに書簡を送付する。

  --agent     送付先の神 (pm|dev|ux|qa)
  --file      送付するタスク定義YAMLファイルのパス
  --task-id   タスクID（省略時はファイル名から推測）
  --from      送信元の神の名（省略時は "八百万システム"）
  --help      この助言を表示
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)  AGENT="$2"; shift 2 ;;
        --file)   TASK_FILE="$2"; shift 2 ;;
        --task-id) TASK_ID="$2"; shift 2 ;;
        --from)   FROM="$2"; shift 2 ;;
        --help)   usage ;;
        *) echo "【禍津】未知の引数: $1"; usage ;;
    esac
done

# --- 入力検証 -------------------------------------------------
if [[ -z "$AGENT" ]]; then
    echo "【禍津】--agent は必須なり。 pm, dev, ux, qa のいずれかを指定せよ。" >&2
    exit 1
fi

VALID=0
for a in "${VALID_AGENTS[@]}"; do
    [[ "$AGENT" == "$a" ]] && VALID=1 && break
done
if [[ $VALID -eq 0 ]]; then
    echo "【禍津】無効なる神の名: '$AGENT'。pm, dev, ux, qa のいずれかを指定せよ。" >&2
    exit 1
fi

if [[ -z "$TASK_FILE" ]]; then
    echo "【禍津】--file は必須なり。" >&2
    exit 1
fi

if [[ ! -f "$TASK_FILE" ]]; then
    echo "【禍津】指定されたタスクファイルが存在せぬ: $TASK_FILE" >&2
    exit 1
fi

if [[ -z "$TASK_ID" ]]; then
    TASK_ID="$(basename "$TASK_FILE" .yaml)"
fi

INBOX_FILE="$INBOX_DIR/$AGENT.yaml"
LOCK_FILE="$INBOX_DIR/.$AGENT.lock"

# 受信トレイファイルが存在しない場合は空ファイルを作成
if [[ ! -f "$INBOX_FILE" ]]; then
    touch "$INBOX_FILE"
fi

# --- 書簡の編纂 -----------------------------------------------
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
MESSAGE_ID="MSG-$(date -u +"%Y%m%d%H%M%S")-$$"

# 書簡ヘッダ
HEADER=$(cat <<YAML
---
message:
  id: "${MESSAGE_ID}"
  from: "${FROM}"
  to: "${AGENT}"
  timestamp: "${TIMESTAMP}"
  task_ref: "${TASK_FILE}"
  task_id: "${TASK_ID}"
  content: |
YAML
)

# 書簡ヘッダとタスク本文をフラット化
TASK_CONTENT=$(sed 's/^/    /' "$TASK_FILE")

# --- 排他ロック付き追記 ---------------------------------------
{
    flock -x 200 || {
        echo "【禍津】書簡の投函に失敗（ロック獲得できず）。しばし待ちて再試行せよ。" >&2
        exit 1
    }

    echo "$HEADER" >> "$INBOX_FILE"
    echo "$TASK_CONTENT" >> "$INBOX_FILE"
    echo "" >> "$INBOX_FILE"

} 200>"$LOCK_FILE"

echo "【奏上】書簡 $MESSAGE_ID を $AGENT の受信トレイに投函せり。"
echo "        送信元: $FROM → 宛先: $AGENT"
echo "        タスク: $TASK_ID"
