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
- Google カレンダーとの**双方向連携**は未実装（現状は .ics 書き出しのみ）。
- iOS はビルド設定のみで配信対象外（Android が本線）。
- 同期は last-write-wins。競合解決のUIは無い。
