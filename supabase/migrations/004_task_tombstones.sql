-- =============================================================================
-- 004 クエスト削除の墓標（tombstone）
-- プロジェクト: kxklkgxpjwddufjccvoj (rpg-task / tsundoku-quest 共用)
--
-- 目的: 「削除したクエストが復活する」の根治。
--   - 削除は行を消すだけでは不十分。cron（創造主タスク自動登録）や
--     他端末・API が同じ id を再登録すると、マージが「クラウドにのみ存在」と
--     判断して復元してしまう。
--   - そこで「この id はユーザーが消した」という事実を永続化する。
--     アプリのマージは墓標の id を採用せず、クラウド側の行も掃除する。
--     cron も墓標の id は再登録しない。
-- 実行方法: Supabase Dashboard → SQL Editor、または supabase db push
-- =============================================================================

CREATE TABLE IF NOT EXISTS rpg_task_tombstones (
  user_id    TEXT        NOT NULL,
  task_id    TEXT        NOT NULL,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  source     TEXT,
  PRIMARY KEY (user_id, task_id)
);

CREATE INDEX IF NOT EXISTS idx_rpg_task_tombstones_user
  ON rpg_task_tombstones(user_id, deleted_at DESC);

ALTER TABLE rpg_task_tombstones ENABLE ROW LEVEL SECURITY;

-- 本人の行のみ読み書きできる（rpg_tasks と同じ規則）。
DROP POLICY IF EXISTS "tombstones_user_access" ON rpg_task_tombstones;
CREATE POLICY "tombstones_user_access" ON rpg_task_tombstones
  FOR ALL
  USING (auth.uid()::text = user_id)
  WITH CHECK (auth.uid()::text = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON rpg_task_tombstones TO anon, authenticated;
GRANT ALL ON rpg_task_tombstones TO service_role;

COMMENT ON TABLE rpg_task_tombstones IS
  'クエスト削除の墓標。削除済み id を再登録・復元させないための台帳（マージ除外＋クラウド掃除）。';
