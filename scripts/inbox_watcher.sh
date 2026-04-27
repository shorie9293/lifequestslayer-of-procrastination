#!/usr/bin/env bash
# ============================================================
# inbox_watcher.sh — 神々の書簡受信監視の儀
#
# 用法:
#   ./inbox_watcher.sh --agent <pm|dev|ux|qa>
#                      [--oneshot] [--on-trigger <script>]
#
# inotifywait を用いて指定された神の受信トレイを監視し、
# 書簡が届き次第、起床の鐘を鳴らす。
# 監視中はブロッキング待機のため CPU 消費は 0%。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUEUE_DIR="$PROJECT_DIR/queue"
INBOX_DIR="$QUEUE_DIR/inbox"

VALID_AGENTS=("pm" "dev" "ux" "qa")

# --- 引数解析 -------------------------------------------------
AGENT=""
ONESHOT=0
TRIGGER_SCRIPT=""

usage() {
    cat <<'EOF'
用法: inbox_watcher.sh --agent <pm|dev|ux|qa>
                       [--oneshot] [--on-trigger <script>]

  指定された神の受信トレイ(queue/inbox/<agent>.yaml)を監視する。

  --agent      監視対象の神 (pm|dev|ux|qa)
  --oneshot    一通の書簡を受け取ったら監視を終了
  --on-trigger 書簡検知時に実行する起床スクリプト（省略時は標準出力に通知）
  --help       この助言を表示
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)       AGENT="$2"; shift 2 ;;
        --oneshot)     ONESHOT=1; shift ;;
        --on-trigger)  TRIGGER_SCRIPT="$2"; shift 2 ;;
        --help)        usage ;;
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

if [[ -n "$TRIGGER_SCRIPT" ]] && [[ ! -x "$TRIGGER_SCRIPT" ]]; then
    echo "【禍津】起床スクリプトが存在しないか、実行権限がない: $TRIGGER_SCRIPT" >&2
    exit 1
fi

INBOX_FILE="$INBOX_DIR/$AGENT.yaml"

# 受信トレイが存在しなければ空で作成（監視対象を存在させる）
if [[ ! -f "$INBOX_FILE" ]]; then
    touch "$INBOX_FILE"
fi

# --- inotifywait の存在確認 --------------------------------
if ! command -v inotifywait &>/dev/null; then
    echo "【禍津】inotifywait が此の神器に見当たらぬ。" >&2
    echo "        inotify-tools を導入せよ: sudo apt install inotify-tools" >&2
    exit 1
fi

# --- 神名の漢字表記 -----------------------------------------
declare -A GOD_NAMES=(
    ["pm"]="思兼神（オモイカネ）"
    ["dev"]="天目一箇神（アメノマヒトツ）"
    ["ux"]="天宇受賣命（アメノウズメ）"
    ["qa"]="月読命（ツクヨミ）"
)

GOD_NAME="${GOD_NAMES[$AGENT]:-$AGENT}"

echo "【奏上】${GOD_NAME} の受信監視を開始せり。"
echo "        書簡を待ちて瞑想に入る——（CPU消費: 0%）"
echo "        Ctrl+C にて監視を終えるべし。"
echo ""

# --- トリガー関数 -------------------------------------------
on_message() {
    local timestamp
    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  【神託降臨】${timestamp}"
    echo "  ${GOD_NAME} の受信トレイに書簡あり！"
    echo "═══════════════════════════════════════════"

    if [[ -n "$TRIGGER_SCRIPT" ]]; then
        # 起床スクリプトにエージェント名と受信トレイパスを渡す
        "$TRIGGER_SCRIPT" "$AGENT" "$INBOX_FILE"
    fi
}

# --- 監視ループ ---------------------------------------------
# close_write: ファイルが書き込みクローズされた
# moved_to:    mv でファイルが配置された（アトミック書簡投函用）
EVENTS="close_write,moved_to"

if [[ $ONESHOT -eq 1 ]]; then
    # 単発監視: 一通検知したら終了
    inotifywait -q -e "$EVENTS" "$INBOX_DIR" --format "%f" 2>/dev/null | while read -r changed_file; do
        if [[ "$changed_file" == "$AGENT.yaml" ]]; then
            on_message
            break
        fi
    done
else
    # 永続監視: 書簡が届くたびに起床
    inotifywait -m -q -e "$EVENTS" "$INBOX_DIR" --format "%f" 2>/dev/null | while read -r changed_file; do
        if [[ "$changed_file" == "$AGENT.yaml" ]]; then
            on_message
        fi
    done
fi
