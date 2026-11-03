-- =============================================================================
-- 002: LifeQuest API v1 用のテーブルと RLS
-- プロジェクト: kxklkgxpjwddufjccvoj（tsundoku-quest と共用）
-- 実行方法: Supabase Dashboard → SQL Editor → このSQLを貼り付けて実行
--           （または `supabase db push`）
-- =============================================================================

-- 1. API トークン（平文は保存しない。SHA-256 ハッシュのみ）
CREATE TABLE IF NOT EXISTS api_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  scopes TEXT[] NOT NULL DEFAULT ARRAY['quests:write'],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_api_tokens_user ON api_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_api_tokens_hash ON api_tokens(token_hash);

-- 2. RLS: 本人のみ参照・発行・失効できる（発行は Phase 2 でアプリから）
ALTER TABLE api_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "api_tokens_owner_access" ON api_tokens;
CREATE POLICY "api_tokens_owner_access" ON api_tokens
  FOR ALL USING (auth.uid()::text = user_id);

-- 3. rpg_tasks のポリシーは 001 のまま（auth.uid()::text = user_id）。
--    Edge Function は service_role で書き込むが、user_id はトークン検証で
--    確定した値のみを使う（クライアント指定は受け付けない）。

-- 4. 監査: トークンの最終使用時刻だけ更新する（本文は残さない）
CREATE OR REPLACE FUNCTION touch_api_token(p_token_id UUID)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE api_tokens SET last_used_at = NOW() WHERE id = p_token_id;
$$;
