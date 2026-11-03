# SPEC.md — LifeQuest Slayer（延鬼討伐伝）の振る舞いの正

> この文書は「いまアプリがどう振る舞うか」の唯一の正である。
> 振る舞いを変えるときは、コードより先にこのファイルを直す。最終更新: 2026-11-03（v1.5.59+155 時点）

## 1. 目的
日常のタスクを RPG のクエストに変換し、完了＝討伐でプレイヤーが成長する。
「やらなければならないこと」への着手コストを、ゲームの報酬構造で下げる。

## 2. 技術構成
- Flutter（Dart SDK ^3.5.4）／状態管理 Provider + ChangeNotifier
- 永続化 Hive（端末）＋ Supabase（同期・認証。`supabase_config.dart`）
- 認証 Supabase Auth（Google サインインは `google_sign_in` 7.x・`serverClientId` 方式）
- 通知 `flutter_local_notifications`（朝の通知・期限リマインダー）
- 監視 Firebase（Crashlytics / Analytics）／課金 `in_app_purchase`
- モノレポ共有パッケージ `takamagahara_ui` / `takamagahara_core`（path 参照）
- 構成: `lib/{core,domain,features,screens}`（feature-first。各 feature は data/domain/presentation を持つ）

## 3. 画面構成（下部ナビ4タブ）
| タブ | 画面 | 役割 |
|------|------|------|
| 修練場 | `features/overview` | 今日の進捗・プレイヤー概要 |
| 寄合所 | `features/guild` | クエスト一覧・作成・編集・検索・一括操作・テンプレート |
| 寺院 | `features/temple` | バックアップ／復元・データ管理 |
| 門前町 | `features/town` | ショップ・振り返りの杜（学びログ・週次報告・内省バッジ） |
- 入口は `lib/screens/main_screen.dart`。認証ゲートは `features/auth/presentation/auth_gate.dart`。

## 4. ドメイン中核：Task（クエスト）
| フィールド | 意味 |
|-----------|------|
| `id` / `title` | 一意ID（uuid）／クエスト名 |
| `status` | `inGuild`（寄合所に未受注）／`active`（受注中） |
| `isCompleted` / `cancelledAt` | 討伐済み／手動取消（取消は再配備を抑制） |
| `rank` | `S` / `A` / `B`（旧 C は読み込み時に B へ移行） |
| `deadline` | 完成期限（期限リマインダー・カレンダー出力の対象） |
| `targetTimeMinutes` | 見積時間（分）。実績との比較で見積精度を算出 |
| `repeatInterval` / `repeatWeekdays` / `repeatAfterDays` | 毎日・毎週（曜日指定）／N日後の再活性化 |
| `subTasks` / `tags` / `activeAt` / `updatedAt` | 子タスク／札／受注日時／同期用更新時刻（last-write-wins） |
| `enemyAssetPath` / `enemyXpMultiplier` | ランク別の敵グラフィック／希少種の経験値倍率 |

- 期限切れの扱い: 期限を過ぎた未完了クエストは「延鬼（のびおに）」として扱う。
- 永続化: `features/guild/data/task_repository.dart`（Hive）＋ `supabase_task_repository.dart`、
  `hybrid_task_repository.dart` がオンライン/オフラインを仲介する。

## 5. 主要機能（feature 単位）
- **guild**: クエスト CRUD・一括操作・検索・スニーズ（延期）・連続討伐（ストリーク）・札・テンプレート・見積精度
- **battle**: 討伐時の戦闘演出・クイズ（KNOWLEDGEクエスト）・戦闘記録
- **reminder**: 期限リマインダー（静音時間 `quiet_hours`・通知タップ遷移 `NotificationRoutes`）
- **streak_freeze**: 連続記録お休み券
- **character_customization / player**: 5部位装備・成長
- **town / temple / kozuchi / habits**: 街の発展・バックアップ・金銭哲学RPG・習慣カレンダー
- **auto_backup**: 定期バックアップ（`full_backup` の JSON を保存・復元・共有）
- **calendar_export**: 未完了クエストの期限を iCalendar(.ics) へ書き出し、共有シートで他アプリへ渡す（読み取り専用・片方向）
- **crossapp / shared / undo / settings / about / account_deletion**: CrossApp 連携・共通UI・Undo・設定・退会

## 6. 不変条件（壊してはいけない振る舞い）
1. 完了済み・取消済みクエストはカレンダー書き出し対象に含めない。
2. カレンダー書き出しの件数表示は「実際に書き出される予定数」と一致させる（虚偽件数を出さない）。
3. 期限なしクエストはカレンダーに載せない（末尾にも置かない＝出力対象外）。
4. 通知・課金・カレンダー等の端末APIは抽象越しに呼び、UI とロジックを分離する。
5. 全操作可能要素に `Semantics` を付与する（アクセシビリティは機能要件）。
6. Hive の TypeAdapter typeId は既存値を再利用しない（破壊的変更になる）。

## 7. バージョンとリリース
- `pubspec.yaml` の `version: 1.5.xx+NNN` が正。AppBar 表示（`guild_screen.dart`）も同期させる。
- main へ `pubspec.yaml` 変更が入ると `deploy.yml` が AAB をビルドし Google Play へ自動デプロイ。
- リリース前は `bash scripts/pre-deploy-check.sh`（analyze＋3シャード）が緑であること。

## 8. 未実装／既知の制約
- Google カレンダーとの連携は**取り込み（読み取り）のみ**。書き込みは .ics 共有（`calendar_export`）が担う。
- iOS はビルド設定のみで配信対象外（Android が本線）。
- 同期は last-write-wins。競合解決のUIは無い。

## 10. API v1（クエスト投入の正門）

外部（AIエージェント・自動化ツール）からクエストを追加する唯一の入口。
`supabase/functions/api/index.ts`（Supabase Edge Functions）。

- エンドポイント: `POST https://<project-ref>.supabase.co/functions/v1/api/v1/quests`
- 認証: `Authorization: Bearer lq_...`（`api_tokens` 表に SHA-256 ハッシュのみ保存。平文は発行時1回だけ表示）
- 公開項目: `id`（任意・冪等キー）/ `title`（必須1〜200字）/ `deadline` / `targetTimeMinutes`（5〜1440）/ `rank`（S,A,B。省略時は見積から自動判定）/ `tags`（最大10・`API` を自動付与）/ `subTasks`（最大50）
- サーバが固定する値: `status = inGuild`・`isCompleted = false`・`repeatInterval = none`。受注はアプリ内で行う
- `deadline` は **JST naive**（`2026-11-10T17:00:00`）で保存する。オフセット付きで渡された場合はサーバがJSTへ正規化する（アプリはローカルnaive前提で表示するため、UTCで保存すると9時間ズレる）
- 冪等性: 同一 `id`・同一内容 → 200／同一 `id`・異なる内容 → 409
- エラー: `{ "error": { "code": ..., "message": ... } }`（401/403/409/422/429）
- **必須キーの完全性**: `Task.fromJson` は `status`/`isCompleted`/`rank`/`repeatInterval` を非nullで読む。1キーでも欠けるとアプリの全件読込が失敗するため、`supabase/functions/api/__fixtures__/quest_data_v1.json` を契約フィクスチャとして `test/features/api/quest_payload_contract_test.dart` で固定している。API の出力形を変えるときは必ずこの試練を通すこと。

## 9. カレンダー連携（`features/calendar_link`）
- 目的: 端末カレンダー（Google アカウント同期分を含む）の予定をクエストとして取り込む。
- 経路: `CalendarImportScreen` → `CalendarGateway`（抽象） → `MethodChannel('com.shorie.lifequest/calendar')` → `CalendarBridge.kt`（CalendarContract 読み取り）。
- 変換規則（`CalendarImportService`）:
  - 期間: 今日 / 3日以内 / 7日以内（今日を1日目とする）
  - 除外: タイトル空・期間外・既存クエストと「題名（正規化）＋日付」が一致・予定同士の重複
  - 期限: 時刻付き＝開始時刻／終日＝その日 23:59
  - 見積: 時刻付き＝所要分（5分未満は None）／終日＝None
  - ランク: 90分以上 S／45分以上 A／それ未満 B
  - 札: `カレンダー`（出所の識別。重複判定には使わない）
- 取り込んだクエストは `inGuild`（寄合所に未受注で並ぶ）。勝手に受注しない。
- 非対応基盤（Web/Desktop/iOS）では `UnsupportedCalendarGateway` が「使えない」を返し、画面は理由を表示する。
