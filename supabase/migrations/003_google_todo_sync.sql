-- =============================================================================
-- 003 Google ToDo（Google Tasks）双方向同期
-- プロジェクト: kxklkgxpjwddufjccvoj (rpg-task / tsundoku-quest 共用)
-- 設計: 同期の頭脳はEdge Function。ここは「結び付け」と「状態」だけを持つ。
-- 実行方法: Supabase Dashboard → SQL Editor、または supabase db push
-- =============================================================================

-- 1. 連携アカウント（service_role 専用。クライアント向けポリシーは作らない）
CREATE TABLE IF NOT EXISTS google_todo_accounts (
  user_id TEXT PRIMARY KEY,
  google_sub TEXT,
  email TEXT,
  list_id TEXT NOT NULL DEFAULT '@default',
  list_title TEXT,
  refresh_token TEXT,
  access_token TEXT,
  access_expires_at TIMESTAMPTZ,
  scopes TEXT[],
  linked_at TIMESTAMPTZ DEFAULT NOW(),
  revoked_at TIMESTAMPTZ
);
ALTER TABLE google_todo_accounts ENABLE ROW LEVEL SECURITY;

-- 2. クエスト⇔Googleタスクの対応表
CREATE TABLE IF NOT EXISTS google_todo_links (
  user_id TEXT NOT NULL,
  local_id TEXT NOT NULL,
  google_task_id TEXT NOT NULL,
  list_id TEXT NOT NULL DEFAULT '@default',
  etag TEXT,
  last_pulled_google_updated TIMESTAMPTZ,
  synced_local_updated_at TIMESTAMPTZ,
  last_synced_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, local_id)
);
CREATE INDEX IF NOT EXISTS idx_google_todo_links_task
  ON google_todo_links(user_id, google_task_id);
ALTER TABLE google_todo_links ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "google_todo_links_read" ON google_todo_links;
CREATE POLICY "google_todo_links_read" ON google_todo_links
  FOR SELECT USING (auth.uid()::text = user_id);

-- 3. 同期状態（画面表示用。読み取りのみ許可）
CREATE TABLE IF NOT EXISTS google_todo_sync_state (
  user_id TEXT PRIMARY KEY,
  last_run_at TIMESTAMPTZ,
  last_ok_at TIMESTAMPTZ,
  last_error TEXT,
  pulled INT DEFAULT 0,
  pushed INT DEFAULT 0
);
ALTER TABLE google_todo_sync_state ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "google_todo_sync_state_read" ON google_todo_sync_state;
CREATE POLICY "google_todo_sync_state_read" ON google_todo_sync_state
  FOR SELECT USING (auth.uid()::text = user_id);

-- 4. OAuth(PKCE) 一時状態（service_role 専用）
CREATE TABLE IF NOT EXISTS google_todo_oauth_states (
  state TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  code_verifier TEXT NOT NULL,
  redirect_uri TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  consumed_at TIMESTAMPTZ
);
ALTER TABLE google_todo_oauth_states ENABLE ROW LEVEL SECURITY;
