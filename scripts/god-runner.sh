#!/usr/bin/env bash
# ============================================================
# god-runner.sh — 全神統括の自律執行神（単一デーモン）
#
# 用法:
#   ./god-runner.sh [--daemon] [--max-concurrent <N>]
#
# 役割:
#   queue/inbox/ 以下全ファイルを監視し、書簡が届き次第
#   opencode-bridge.sh を呼び出して自律実行する。
#   単一プロセスで全神（PM/Dev/UX/QA）のタスクを逐次処理する。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INBOX_DIR="$PROJECT_DIR/queue/inbox"
TASKS_DIR="$PROJECT_DIR/queue/tasks"

VALID_AGENTS=("pm" "dev" "ux" "qa")
declare -A GOD_NAMES=(
  ["pm"]="思兼神（オモイカネ）"
  ["dev"]="天目一箇神（アメノマヒトツ）"
  ["ux"]="天宇受賣命（アメノウズメ）"
  ["qa"]="月読命（ツクヨミ）"
)

# --- 引数解析 -------------------------------------------------
DAEMON=0
MAX_CONCURRENT=1

usage() {
    cat <<'EOF'
用法: god-runner.sh [--daemon] [--max-concurrent <N>]

  全神の書簡受信トレイを監視し、届き次第OpenCodeで自律実行する。

  --daemon           永続監視モード（Ctrl+C で終了）
  --max-concurrent   最大同時実行数（デフォルト: 1）
  --help             この助言を表示
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --daemon)          DAEMON=1; shift ;;
        --max-concurrent)  MAX_CONCURRENT="$2"; shift 2 ;;
        --help)            usage ;;
        *) echo "【禍津】未知の引数: $1"; usage ;;
    esac
done

# --- 依存確認 ---------------------------------------------------
if ! command -v inotifywait &>/dev/null; then
    echo "【禍津】inotify-tools が此の神器に見当たらぬ。" >&2
    echo "        sudo apt install inotify-tools" >&2
    exit 1
fi

# 受信トレイディレクトリがなければ作成
mkdir -p "$INBOX_DIR" "$TASKS_DIR"

# --- 単発モード: 未処理の書簡をすべて処理して終了 ----------------
process_all_pending() {
    local processed=0
    for agent in "${VALID_AGENTS[@]}"; do
        local inbox_file="$INBOX_DIR/$agent.yaml"
        if [[ ! -f "$inbox_file" ]] || [[ ! -s "$inbox_file" ]]; then
            continue
        fi

        # 書簡からタスク参照を抽出
        local task_file
        task_file=$(grep "task_ref:" "$inbox_file" | head -1 | sed 's/.*task_ref:[[:space:]]*"//;s/".*//')

        if [[ -z "$task_file" ]] || [[ ! -f "$PROJECT_DIR/$task_file" ]]; then
            echo "【禍津】${GOD_NAMES[$agent]} の書簡に有効な task_ref なし、スキップ"
            continue
        fi

        local task_id
        task_id=$(grep "task_id:" "$inbox_file" | head -1 | sed 's/.*task_id:[[:space:]]*"//;s/".*//')

        echo ""
        echo "═══════════════════════════════════════════"
        echo "  【執行開始】${GOD_NAMES[$agent]}"
        echo "  タスク: $task_id"
        echo "═══════════════════════════════════════════"

        # ブリッジを実行
        "$SCRIPT_DIR/opencode-bridge.sh" \
            --task-file "$PROJECT_DIR/$task_file" \
            --timeout 600 || true

        # 処理済み書簡をバックアップし削除
        local processed_dir="$INBOX_DIR/.processed"
        mkdir -p "$processed_dir"
        mv "$inbox_file" "$processed_dir/$(date +%Y%m%d%H%M%S)_$agent.yaml"
        processed=$((processed + 1))
    done

    if [[ $processed -eq 0 ]]; then
        echo "【奏上】未処理の書簡はない。静かに眠るがよい。"
    else
        echo ""
        echo "【奏上】${processed}件の神託を処理し終えた。"
    fi
}

# --- 永続監視モード（デーモン）----------------------------------
run_daemon() {
    echo "【奏上】全神統括の自律執行神、起動せり。"
    echo "        ${INBOX_DIR} を監視し、書簡を待つ——"
    echo ""

    # 起動時に未処理をクリア
    process_all_pending

    # 永続監視ループ
    inotifywait -m -q -e close_write,moved_to "$INBOX_DIR" --format "%f" 2>/dev/null | while read -r changed_file; do
        for agent in "${VALID_AGENTS[@]}"; do
            if [[ "$changed_file" != "$agent.yaml" ]]; then
                continue
            fi

            local inbox_file="$INBOX_DIR/$agent.yaml"
            if [[ ! -s "$inbox_file" ]]; then
                continue
            fi

            # 少し待って完全に書き込まれたことを確認
            sleep 1

            local task_file
            task_file=$(grep "task_ref:" "$inbox_file" | head -1 | sed 's/.*task_ref:[[:space:]]*"//;s/".*//')

            if [[ -z "$task_file" ]] || [[ ! -f "$PROJECT_DIR/$task_file" ]]; then
                echo "【禍津】${GOD_NAMES[$agent]} の書簡に有効な task_ref なし"
                continue
            fi

            local task_id
            task_id=$(grep "task_id:" "$inbox_file" | head -1 | sed 's/.*task_id:[[:space:]]*"//;s/".*//')

            echo ""
            echo "═══════════════════════════════════════════"
            echo "  【執行開始】${GOD_NAMES[$agent]}"
            echo "  タスク: $task_id"
            echo "═══════════════════════════════════════════"

            "$SCRIPT_DIR/opencode-bridge.sh" \
                --task-file "$PROJECT_DIR/$task_file" \
                --timeout 600 || true

            local processed_dir="$INBOX_DIR/.processed"
            mkdir -p "$processed_dir"
            mv "$inbox_file" "$processed_dir/$(date +%Y%m%d%H%M%S)_$agent.yaml"

            echo "【奏上】${GOD_NAMES[$agent]} の神託 ${task_id} を処理し終えた。次の書簡を待つ——"
            echo ""
        done
    done
}

# --- メイン -----------------------------------------------------
cd "$PROJECT_DIR"

if [[ $DAEMON -eq 1 ]]; then
    run_daemon
else
    process_all_pending
fi
