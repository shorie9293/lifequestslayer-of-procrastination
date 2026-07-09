-- =============================================================================
-- rpg-task Supabase テーブル作成スクリプト
-- プロジェクト: kxklkgxpjwddufjccvoj (tsundoku-quest と共用)
-- 実行方法: Supabase Dashboard → SQL Editor → このSQLを貼り付けて実行
-- =============================================================================

-- 1. クエストテーブル
CREATE TABLE IF NOT EXISTS rpg_tasks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  data JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rpg_tasks_user ON rpg_tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_rpg_tasks_updated ON rpg_tasks(updated_at DESC);

-- 2. プレイヤーテーブル
CREATE TABLE IF NOT EXISTS rpg_players (
  user_id TEXT PRIMARY KEY,
  data JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Row Level Security 有効化
ALTER TABLE rpg_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE rpg_players ENABLE ROW LEVEL SECURITY;

-- 4. RLS ポリシー: ユーザーは自分のデータのみアクセス可能
DROP POLICY IF EXISTS "tasks_user_access" ON rpg_tasks;
CREATE POLICY "tasks_user_access" ON rpg_tasks
  FOR ALL USING (auth.uid()::text = user_id);

DROP POLICY IF EXISTS "players_user_access" ON rpg_players;
CREATE POLICY "players_user_access" ON rpg_players
  FOR ALL USING (auth.uid()::text = user_id);

-- 5. 匿名ユーザーも自分のデータにアクセス可能（anon key用）
-- Supabase の anon key は RLS を通過するため、上記ポリシーで十分
