# 設計判断の履歴

「なぜこうなっているか」を1判断1節で残す。**新しい判断は上に追記**（新しい順）。
書式: 日付／判断／理由／代替案を捨てた理由／根拠（ファイル）。

---

## 2026-11-03 エージェント運用文書（AGENTS.md / SPEC.md / 本ファイル）を新設
- 判断: エージェント（Muse=駿麒 等）の作業規約を repo 内の文書で拘束する。
- 理由: 外部エージェントはセッションを跨いで記憶しない。規約はリポジトリに置くしかない。
- 代替案: プロンプトで毎回指示 → 長文化・漏れ・版管理不能で却下。
- 根拠: `AGENTS.md`, `SPEC.md`, `docs/muse-operations.md`

## 2026-11-03 カレンダー連携は「端末カレンダー読み取り」を第一弾とする
- 判断: Google Calendar API + OAuth ではなく、Android の CalendarContract を抽象ゲートウェイ越しに読む。
- 理由: 機密スコープの OAuth は公開アプリで Google の審査が必要（数週間）。端末カレンダーは Google アカウントの予定も端末同期経由で読め、審査不要でオフラインでも動く。
- 代替案: OAuth API 直結 → 第二弾に保留（サーバ側同期が必要になった時点で再評価）。
- 制約: Android のみ。`READ_CALENDAR` 権限と Play Console のデータセーフティ申告が必要。書き込みは既存 .ics 共有が担う。
- 根拠: `lib/features/calendar_link/`, `android/app/src/main/kotlin/com/shorie/lifequest/CalendarBridge.kt`

## 2026-11-03 永続化は Hive を継続（Isar へ移行しない）
- 判断: 既存の Hive スキーマを維持する。
- 理由: 評価の結論として移行コストが便益を上回る。
- 根拠: `docs/hive_to_isar_evaluation.md` 四章

## 2026-09-xx オフライン同期は last-write-wins
- 判断: `updatedAt` の比較で新しい側を採用する。競合解決UIは持たない。
- 理由: 個人用タスク管理で同時編集は稀。UI を作るコストに見合わない。
- 根拠: `lib/domain/models/task.dart`（`updatedAt`）、`hybrid_task_repository.dart`

## 2026-xx-xx カレンダー書き出しは .ics 共有（読み取り専用・片方向）
- 判断: OS の共有シートで .ics を渡す方式。カレンダーへの直接書き込みはしない。
- 理由: 権限も OAuth も要らず、どのカレンダーアプリにも渡せる。プラットフォーム非依存。
- 根拠: `lib/features/calendar_export/`
