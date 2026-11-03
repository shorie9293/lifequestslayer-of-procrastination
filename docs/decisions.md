# 設計判断の履歴

「なぜこうなっているか」を1判断1節で残す。**新しい判断は上に追記**（新しい順）。
書式: 日付／判断／理由／代替案を捨てた理由／根拠（ファイル）。

---

## 2026-11-03 同期の差分削除を廃止し、削除は deleteTasks() の明示APIに限定
- 判断: `SupabaseTaskRepository.saveTasks` から「クラウドにあって手元にないIDを削除」する処理を撤去。削除は `ITaskDeletionRepository.deleteTasks` で明示的に行う。
- 理由: 手元が古い一覧のまま保存された瞬間、他端末や API が入れた行まで消える（データ喪失）。API 投入と両立しない。
- 併せて: `loadTasks` を「行単位で読み取り、壊れた行だけスキップ」に変更（全件throw→`[]` 返しは、同期がクラウドを取りこぼしたまま書き戻す事故の引き金になる）。
- 代替案: `quest_inbox`（受け箱）分離 → diff削除を残す前提の回避策でアプリ改修も必要。diff削除自体を直せば不要と判断。
- 根拠: `lib/features/guild/data/supabase_task_repository.dart`, `lib/domain/repositories/i_task_deletion_repository.dart`, `test/features/guild/data/task_deletion_sync_test.dart`

## 2026-11-03 外部からの投入は Edge Functions の API v1 を正門とする
- 判断: DB 直アクセスや service_role 鍵の配布はしない。`POST /v1/quests` のみを公開し、`user_id` はトークン検証で確定した値だけを使う。
- 理由: 正門を1つに絞れば、検証・冪等性・監査を1箇所に集約できる。MCP は後からこの API のクライアントとして足せる。
- 併せて: `deadline` は JST naive で保存（アプリがローカルnaive前提で表示するため）。必須キーは契約フィクスチャで固定。
- 代替案: Supabase の auto-REST（PostgREST）をそのまま外部公開 → 内部形式（`Task.toJson`）が公開契約になり、アプリの内部変更で外部が壊れるため却下。
- 根拠: `supabase/functions/api/index.ts`, `supabase/migrations/002_api_tokens.sql`, `test/features/api/quest_payload_contract_test.dart`

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
