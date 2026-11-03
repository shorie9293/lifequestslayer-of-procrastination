# LifeQuest API 設計書 v1（案）

- 制定: 2026-11-03 ／ 起案: 駿麒（Muse）
- 状態: **案**。§11 の未決事項は創造主の裁定待ち
- 対象: `shorie9293/lifequestslayer-of-procrastination`（LifeQuest / 延鬼討伐伝、v1.5.59+155 時点）
- 前提文書: `SPEC.md`（振る舞いの正）、`AGENTS.md`（作業規約）、`docs/muse-operations.md`（Muse 運用）
- 位置づけ: 本書は公開 API / MCP の設計であり、アプリの現行の振る舞い（SPEC）を変えるものではない

## 1. 目的と非目的

目的:
- Muse 等の AI エージェント、自動化ツール、将来の他ユーザー製クライアントが、**アプリの外からクエストを追加できる**公式の入口を作る
- その入口を、将来そのまま **API および MCP として他ユーザーへ提供できる**形にする

非目的:
- データベース（Supabase）への直接アクセスの公開はしない（§3-1）
- アプリ内操作（受注・討伐演出・課金等）の外部化はしない。v1 の対象は「クエストの追加」と、段階を置いた「一覧・完了」のみ

## 2. 全体構成

```
クライアント（Muse / 他AI / Zapier / ショートカット / 将来の他ユーザー）
        │  （MCP の場合は下の MCP サーバ経由。それ以外は直接）
        ▼
MCP サーバ（薄いラッパー。API クライアントとしてのみ動く）
        │
        ▼
REST API v1 ― Supabase Edge Functions
  ・認証（トークン検証 → user_id 確定）
  ・入力検証 / 冪等性 / レート制限
  ・公開形式 → 内部形式への翻訳
        │  （検証済み user_id の権限で書き込む。RLS を通す）
        ▼
Supabase 表 `rpg_tasks`（現行形式のまま）
        │
        ▼
アプリ（現行の hybrid 同期がクラウドのみの行を取り込む → 寄合所 `inGuild` に並ぶ）
```

要点: **API が資産、MCP はその利用形態の1つ**。MCP を先に作り込まない。

## 3. 設計原則

1. **正門は API のみ**。service_role 鍵・DB 直接接続・`rpg_tasks` の生形式は、外部（他ユーザーはもちろん、AI エージェント含む）に渡さない。service_role が必要な処理があっても Edge Function の内側だけに閉じ、鍵そのものは外に出ない
2. **公開形式と内部形式を分離する**。公開スキーマ（§4）は API が所有し、内部の `Task.toJson()` 形式へは API が翻訳する。アプリ内部のリファクタリングでは公開 API は壊れない。逆に公開形式の変更は §9 の版管理に従う
3. **user_id は認証からだけ決まる**。リクエストボディで user_id を受け付けない（指定されても無視／エラー）。他人のクエストは読めない・書けない（RLS `user_id = auth.uid()` 相当を API でも強制）
4. **冪等性を必須とする**。AI に投げさせる入口は再送が前提。クエスト ID（UUID）をクライアントが指定でき、同一 ID の再投入で二重登録にならない（§5-3）
5. **最小権限・失効可能**。鍵は用途別のスコープを持ち、いつでも失効できる。平文では保存しない（§7）

## 4. 公開リソース: Quest（v1）

| 項目 | 型 | 必須 | 既定値・規則 |
|------|----|------|--------------|
| `id` | UUID 文字列 | 任意 | 省略時はサーバが採番。指定時は冪等キーとして扱う（§5-3） |
| `title` | 文字列 | **必須** | 1〜200 文字。前後の空白は除去。空は 422 |
| `deadline` | ISO 8601 文字列 | 任意 | タイムゾーンオフセット付きを推奨（例 `2026-11-10T17:00:00+09:00`）。省略 = 期限なし |
| `targetTimeMinutes` | 整数（分） | 任意 | 5〜1440 |
| `rank` | `"S"` / `"A"` / `"B"` | 任意 | 省略時は見積から自動判定（§6 注記。calendar_link と同一規則） |
| `tags` | 文字列の配列 | 任意 | 最大10件・各30文字まで。サーバが札 `API` を必ず追加する（§6） |
| `subTasks` | `{title}` の配列 | 任意 | 最大50件。各 title は1〜200文字 |

サーバが固定で決める項目（クライアントは指定できない）: 状態は常に `inGuild`（寄合所・未受注）で作成する。受注はアプリ内で行う ― カレンダー取り込みと同じ振る舞い。

リクエスト例:

```json
{
  "id": "3f9a1c2e-7b4d-4e8f-9a0b-1c2d3e4f5a6b",
  "title": "確定申告の書類を揃える",
  "deadline": "2026-11-10T17:00:00+09:00",
  "targetTimeMinutes": 60,
  "tags": ["手続き"],
  "subTasks": [{ "title": "源泉徴収票を印刷" }, { "title": "医療費の領収書を集計" }]
}
```

レスポンス例（201）:

```json
{ "id": "3f9a1c2e-7b4d-4e8f-9a0b-1c2d3e4f5a6b", "status": "inGuild", "createdAt": "2026-11-03T12:30:00Z" }
```

## 5. エンドポイント

ベース: `https://<project-ref>.supabase.co/functions/v1`（Edge Functions）

| 段階 | メソッドとパス | 内容 |
|------|----------------|------|
| Phase 1（必須） | `POST /v1/quests` | クエストを1件追加 |
| Phase 2 | `GET /v1/quests?status=inGuild\|active` | 自分のクエスト一覧（既定は未完了のみ） |
| Phase 2 | `POST /v1/quests/{id}/complete` | 完了にする（アプリ側の討伐演出は伴わない。記録のみ） |
| 対象外 | 削除・編集の一括操作 | v1 では扱わない（アプリ内で行う） |

### 5-1. エラー形式

```json
{ "error": { "code": "validation_failed", "message": "title is required" } }
```

| HTTP | code | 意味 |
|------|------|------|
| 401 | `unauthenticated` | トークンなし／無効／失効済み |
| 403 | `insufficient_scope` | スコープ不足（例: 読取専用トークンで追加） |
| 409 | `id_conflict` | 同一 `id` で内容の異なる再投入 |
| 422 | `validation_failed` | 入力検証エラー（項目名を message に含める） |
| 429 | `rate_limited` | レート制限（§8） |

### 5-2. 認証ヘッダ

`Authorization: Bearer <token>`（§7）。Phase 3 以降は Supabase Auth の JWT も同じヘッダで受け付ける。

### 5-3. 冪等性

- クライアントが `id` を指定した場合、その ID が主キーになる
- 同一 ID・同一内容の再送 → **200** で既存を返す（新規作成と区別しないでよい）
- 同一 ID・異なる内容 → **409**（上書きはしない。last-write-wins の事故を入口で防ぐ）

## 6. 内部変換（公開形式 → `rpg_tasks`）

行の形は現行どおり: `id` / `user_id`（認証から確定）/ `data`（`Task.toJson()` 形式の JSONB）/ `updated_at`。

`data` への対応:

| 公開項目 | 内部項目 | 値 |
|----------|----------|----|
| `id` | `id` | そのまま |
| `title` | `title` | そのまま |
| ― | `status` | `"inGuild"` 固定 |
| ― | `isCompleted` | `false` |
| `rank` | `rank` | 指定値。省略時は自動判定（下記） |
| ― | `repeatInterval` / `repeatWeekdays` / `repeatAfterDays` | `"none"` / `[]` / `null` |
| `subTasks` | `subTasks` | `{title, isCompleted: false}` に展開 |
| `targetTimeMinutes` | `targetTimeMinutes` | そのまま |
| `deadline` | `deadline` | そのまま |
| `tags` | `tags` | クライアントの札 ＋ `API`（出所の識別。重複時は1つ） |
| ― | `lastCompletedAt` / `activeAt` / `cancelledAt` | `null` |
| ― | `enemyAssetPath` | `null`（下記の先例により安全） |
| ― | `enemyXpMultiplier` | `1.0` |
| ― | `updatedAt` | API の受付時刻（サーバ時刻） |

根拠（コードで確認済み）:
- カレンダー取り込み `CalendarImportService.buildTask` が、まさにこの最小構成（id / title / rank / targetTimeMinutes / deadline / tags のみ指定、残りは Task の既定値 = `enemyAssetPath: null` 等）でクエストを生成し、実運用されている。API 投入はこの先例と同形にする
- ランク自動判定も同サービスの規則を流用する: 見積90分以上 = S、45分以上 = A、それ未満・不明 = B
- 取り込みの重複除外（題名＋日付）はアプリ側の既存クエストにも効くため、API 投入分が後からカレンダー取り込みで二重化することもない

## 7. 認証と鍵

### 7-1. 個人トークン（Phase 1〜）

- 形式: `lq_` プレフィックス付きの十分に長いランダム文字列。**発行時に1回だけ表示**し、DB には SHA-256 ハッシュのみ保存する
- 保管表（新規）`api_tokens`:

| 列 | 内容 |
|----|------|
| `id` | UUID |
| `user_id` | 所有者（Supabase Auth のユーザー） |
| `name` | 用途メモ（例: `Muse`、`zapier`） |
| `token_hash` | ハッシュのみ。平文は持たない |
| `scopes` | 例: `quests:write` / `quests:read` |
| `created_at` / `last_used_at` / `revoked_at` | 発行・最終使用・失効 |

- Phase 1 では発行は管理画面（Supabase ダッシュボード / SQL）で本人分のみ。Phase 2 でアプリ内「設定 → 連携トークン」から本人が発行・失効できるようにする
- Edge Function はトークンを検証し、`user_id` とスコープを確定してから処理する。書き込みは、その `user_id` の権限として RLS を通すのが本線

### 7-2. 将来の認証（Phase 3）

- 一般ユーザー向けには Supabase Auth の JWT（Google サインイン、既存）を受け付ける
- リモート MCP の認証は OAuth 2.1 を標準とし、個人トークンは開発者向けに残す

## 8. 安全策

- **レート制限（案）**: トークンあたり 60 リクエスト/分、1,000 リクエスト/日。超過は 429
- **削除同期のハザード（既知）**: アプリ側 `SupabaseTaskRepository.saveTasks` は「ローカル一覧に無い行を削除」する同期を含む。API で投入した直後、アプリが古い一覧のまま保存すると、取り込み前の行が消えうる
  - Phase 1 の運用策: 投入直後は、他の編集より先にアプリを開いて取り込ませる
  - 製品化（Phase 3）前の本対策は §11-3 で裁定する（受け箱テーブル分離が本命。カレンダー取り込みと同型の「受け箱 → 選んで取り込み／自動取り込み」が既存パターンと揃う）
- **監査**: Phase 2 で `api_requests` ログ（user_id / エンドポイント / 結果 / 時刻）を残す。クエスト本文はログに残さない

## 9. MCP 設計（Phase 3）

- トランスポート: リモート MCP（Streamable HTTP）。MCP サーバは API のクライアントであり、DB へ直接触れない
- ツールは API と1対1に薄く対応させる:

| MCP ツール | 対応 API | 引数 |
|------------|----------|------|
| `quest_add` | `POST /v1/quests` | `title`（必須）、`deadline`、`targetTimeMinutes`、`rank`、`tags`、`subTasks`、`id`（任意） |
| `quest_list` | `GET /v1/quests` | `status`（任意） |
| `quest_complete` | `POST /v1/quests/{id}/complete` | `id` |

- 戻り値は API のレスポンスをそのまま構造化して返す（MCP 側で独自の整形をしない）

## 10. 版管理

- パスに版を含める（`/v1/`）。公開形式の後方互換を保つ変更（項目追加）は同一版で可。互換を壊す変更は `/v2/` を新設し、v1 は移行期間を置いて閉じる
- 内部形式（`Task.toJson()`）の変更では公開版は上げない（§3-2 の翻訳層が吸収する）

## 11. 段階計画と受け入れ基準

### Phase 1 ― 個人用（アプリ無変更の見込み）
- Edge Function `POST /v1/quests` ＋ `api_tokens` 表 ＋ 必要な RLS ポリシー追加（Supabase 側の作業のみ）
- 事前確認: 現行の `rpg_tasks` の RLS ポリシーの内容（リポジトリからは見えない。ダッシュボードで確認する）
- 受け入れ基準:
  - [ ] 正しいトークンの curl で投入 → アプリを開くと寄合所にそのクエストが並ぶ（題名・期限・見積・ランク・札が一致）
  - [ ] トークンなし／失効トークン → 401
  - [ ] 同一 `id` の同一内容を2回送信 → クエストは1件のまま
  - [ ] 他ユーザーのトークンで投入しても、自分の寄合所には現れない

### Phase 2 ― アプリ連携
- アプリ内トークン発行・失効画面、`GET /v1/quests` と完了 API、OpenAPI 仕様の公開、監査ログ
- アプリ変更を伴うため、リリースは通常の版管理（`pubspec.yaml` の bump = Play 配信）に従い、創造主の裁定で実施する

### Phase 3 ― MCP と他ユーザー
- リモート MCP サーバ公開、OAuth 2.1、削除同期ハザードの本対策（§11-3 の裁定に従う）

### 未決事項（裁定待ち）
1. Phase 1 のトークン発行は管理画面で本人分のみ、で開始してよいか
2. ランク自動判定はカレンダー取り込みの規則（90分=S / 45分=A）の流用でよいか
3. 削除同期ハザードの本対策は「受け箱テーブル（`quest_inbox`）分離」とする方針でよいか。それとも Phase 1 から受け箱方式にするか（その場合はアプリ側の取り込み実装が Phase 1 から必要になり、「アプリ無変更」の利点は消える）
4. 完了 API（`quest_complete`）を Phase 2 でなく Phase 1 に前倒す必要があるか
