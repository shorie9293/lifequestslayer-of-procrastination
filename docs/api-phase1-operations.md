# LifeQuest API v1 — Phase 1 運用ガイド

対象: Supabase プロジェクト `kxklkgxpjwddufjccvoj`（tsundoku-quest と共用）
正本: `supabase/functions/api/index.ts` / `supabase/migrations/002_api_tokens.sql` / `SPEC.md` §10

## 0. 前提
- Phase 1 は **クエストの追加（`POST /v1/quests`）のみ**。一覧・完了は Phase 2。
- 投入されたクエストは `inGuild`（寄合所・未受注）で並ぶ。受注はアプリ内で行う。
- **アプリを開いたままだと取り込まれない**。投入後はアプリを再起動（または再読込）して同期させる。

## 1. 初回セットアップ（1回だけ）

### 1-1. DDL の適用
Supabase ダッシュボード → SQL Editor で `supabase/migrations/002_api_tokens.sql` を実行。

```sql
-- 実行後、確認
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'api_tokens';
-- → api_tokens が1行返ればOK
```

### 1-2. 関数のデプロイ
```bash
cd ~/Takamagahara/utsushiyo/rpg-task
supabase functions deploy api --project-ref kxklkgxpjwddufjccvoj
```
`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` は Edge Functions の既定シークレットとして自動注入される（追加設定不要）。

## 2. トークンの発行（本人分のみ）

平文は**発行時の1回だけ**表示する。DB には SHA-256 ハッシュしか残らない。
`<USER_ID>` は Supabase Auth の uid（Google サインインのユーザー）。

```bash
# 1) トークン生成とハッシュ計算（ローカルで実行。平文はここでしか出ない）
TOKEN="lq_$(openssl rand -hex 32)"
HASH=$(printf '%s' "$TOKEN" | sha256sum | cut -d' ' -f1)
echo "TOKEN=$TOKEN"
echo "HASH=$HASH"
```

```sql
-- 2) Supabase SQL Editor で登録
INSERT INTO api_tokens (user_id, name, token_hash, scopes)
VALUES ('<USER_ID>', 'Muse', '<HASH>', ARRAY['quests:write']);
```

```sql
-- 3) 発行済みの確認（ハッシュは見えるが平文は見えない）
SELECT id, name, scopes, created_at, last_used_at FROM api_tokens;
```

### 失効
```sql
UPDATE api_tokens SET revoked_at = NOW() WHERE name = 'Muse';
```

## 3. 動作確認（curl）

```bash
BASE="https://kxklkgxpjwddufjccvoj.supabase.co/functions/v1/api"
TOKEN="lq_..."

# 正常投入（201）
curl -sS -o /tmp/lq.json -w "%{http_code}\n" -X POST "$BASE/v1/quests" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title":"確定申告の書類を揃える","deadline":"2026-11-10T17:00:00+09:00","targetTimeMinutes":60,"tags":["手続き"]}'
cat /tmp/lq.json

# 冪等（同一ID・同一内容 → 200）
ID=$(python3 -c "import json;print(json.load(open('/tmp/lq.json'))['id'])")
curl -sS -o /dev/null -w "%{http_code}\n" -X POST "$BASE/v1/quests" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d "{\"id\":\"$ID\",\"title\":\"確定申告の書類を揃える\",\"deadline\":\"2026-11-10T17:00:00+09:00\",\"targetTimeMinutes\":60,\"tags\":[\"手続き\"]}"

# 401（トークンなし）
curl -sS -o /dev/null -w "%{http_code}\n" -X POST "$BASE/v1/quests" \
  -H "Content-Type: application/json" -d '{"title":"x"}'

# 422（title 欠落）
curl -sS -X POST "$BASE/v1/quests" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'
```

## 4. 受け入れ確認（アプリ側）
1. 投入後にアプリを起動 → 寄合所にクエストが並ぶ
2. 題名・期限・見積・ランク・札（`API` を含む）が投入内容と一致
3. 期限が **JST のまま**表示される（9時間ズレていない）
4. 投入したクエストを削除 → 再起動しても復活しない（`deleteTasks` 経路の確認）

## 5. 既知の制約
- `deadline` は JST naive 固定（他タイムゾーンのユーザーには未対応）
- レート制限は未実装（トークン失効で対処）。乱用が見えたら Phase 2 で DB カウンタを入れる
- トークン発行は SQL 手作業（Phase 2 でアプリ内発行に移す）
- アプリが古い一覧を持ったまま保存しても、もうクラウドの行は消えない（差分削除を撤去済み）
