# 【神具連携の手引】OpenClaw × OpenCode Go 統合

**最終更新**: 2026-04-27
**対象**: 創造主様・天津機巧神

---

## 概要

OpenClaw（Claw Empire）から OpenCode Go の神々（PM/Dev/UX/QA）を召喚し、
自律的にタスクを実行させるための連携基盤である。

### 全体の流れ

```
OpenClaw
  │
  │ ① タスクYAMLを queue/tasks/ に作成
  │ ② inbox_write.sh で神の受信トレイに投函
  ▼
god-runner.sh（常駐デーモン）
  │
  │ ③ inotifywait で書簡を検知
  │ ④ opencode-bridge.sh を起動
  ▼
opencode run --agent omoiKane --model opencode-go/deepseek-v4-pro
  │
  │ ⑤ OpenCodeが自律実行（コード修正・ファイル操作）
  ▼
queue/reports/<task_id>_done.yaml
  │
  │ ⑥ OpenClawが結果を読み取り、次タスクを決定
  ▼
[自律連携サイクル]
```

---

## 1. 前提条件

```bash
# OpenCode 導入
curl -fsSL https://opencode.ai/install | bash

# inotify-tools（ファイル監視用）
sudo apt install inotify-tools

# OpenClaw（未導入時）
# ※ OpenClaw は別途導入が必要。導入後、以下の手順で連携する。
```

---

## 2. タスクの投函方法（OpenClaw側）

### 2-1. タスクYAMLの作成

`queue/tasks/` に以下の形式でYAMLファイルを作成する：

```yaml
task_id: "TASK-RPT-001"
title: "ログイン画面のUI修正"
assigned_to: "dev"          # pm | dev | ux | qa
priority: "high"
created_at: "2026-04-27T10:00:00Z"
blockedBy: []
context: |
  home_screen.dart のログインボタンの色を
  プライマリカラーに統一すること。
  既存の ColorScheme を使用し、新規色の追加は避けよ。
artifacts:
  spec_ref: "utsushiyo/rpg-task/shinso.md"
```

### 2-2. inbox_write.sh で投函

```bash
# OpenClaw がタスクを天目一箇神（Dev）に投函
utsushiyo/rpg-task/scripts/inbox_write.sh \
  --agent dev \
  --file queue/tasks/TASK-RPT-001.yaml \
  --task-id TASK-RPT-001 \
  --from OpenClaw
```

---

## 3. 自律実行の開始

### 3-1. 常駐デーモンの起動

```bash
cd utsushiyo/rpg-task

# 永続監視モード（Ctrl+Cで終了）
./scripts/god-runner.sh --daemon

# または未処理の書簡のみ処理
./scripts/god-runner.sh
```

### 3-2. 手動実行（単発）

```bash
# ドライラン（プロンプトのみ表示、実行しない）
./scripts/opencode-bridge.sh \
  --task-file queue/tasks/TASK-RPT-001.yaml \
  --dry-run

# 実際に実行
./scripts/opencode-bridge.sh \
  --task-file queue/tasks/TASK-RPT-001.yaml \
  --timeout 600
```

---

## 4. 神々へのタスク割り当て

| assigned_to | 神名 | OpenCode Agent | モデル | 適したタスク |
|-------------|------|---------------|--------|------------|
| `pm` | 思兼神 | `omoiKane` | deepseek-v4-pro | 仕様策定、ロードマップ、優先順位付け |
| `dev` | 天目一箇神 | `amenoMahitotsu` | kimi-k2.6 | 実装、リファクタリング、バグ修正 |
| `ux` | 天宇受賣命 | `amenoUzume` | qwen3.6-plus | UI/UX監査、デザイン提案、アクセシビリティ |
| `qa` | 月読命 | `tsukuyomi` | deepseek-v4-flash | テスト生成、バグ探索、品質監査 |

---

## 5. 完了報告の読み取り

`queue/reports/<task_id>_done.yaml` に結果が出力される：

```yaml
task_id: "TASK-RPT-001"
status: "completed"         # completed | failed
completed_at: "2026-04-27T11:30:00Z"
assigned_to: "dev"
model: "opencode-go/kimi-k2.6"
summary: |
  ログインボタンの色を ColorScheme.primary に変更しました。
  変更ファイル: lib/screens/home_screen.dart
artifacts:
  raw_log: "/tmp/..."
```

---

## 6. 依存タスクの管理

タスク間の依存関係は `blockedBy` で指定する：

```yaml
task_id: "TASK-RPT-003"
blockedBy: ["TASK-RPT-001", "TASK-RPT-002"]
```

`god-runner.sh` は `blockedBy` を参照せず即時実行するため、
依存管理は OpenClaw 側で行うこと。
（`blockedBy` の完了を確認してから投函する。）

---

## 7. トラブルシューティング

| 問題 | 原因 | 対策 |
|------|------|------|
| `opencode: command not found` | OpenCode未導入 | `curl -fsSL https://opencode.ai/install \| bash` |
| `inotifywait: not found` | inotify-tools未導入 | `sudo apt install inotify-tools` |
| タスクが実行されない | 書簡の task_ref が不正 | inboxのYAML内の `task_ref:` を確認 |
| タイムアウト | 複雑なタスク | `--timeout 1200` で延長 |
| 宝石消失 | C3バグ | v1.2.1で修正済み |
