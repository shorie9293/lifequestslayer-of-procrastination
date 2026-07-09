# rpg-task Supabase連携 実装計画

> **神託**: 創造主様「今すぐ進めて」— 令和八年七月九日
> **方針**: Hiveを主としSupabaseを副とするハイブリッド永続化。UI層変更ゼロ。

**Goal**: rpg-task に Supabase クラウド同期を追加し、複数デバイス間でタスク・冒険者データを共有可能にする。

**Architecture**: `ITaskRepository`/`IPlayerRepository` の実装を `HiveXxxRepository` → `HybridXxxRepository`（Hiveローカル + Supabaseクラウド二重書き込み）に差し替え。`toJson()`/`fromJson()` が完備されているためJSONBカラムで直接格納。

**Tech Stack**: supabase_flutter, Supabase匿名認証, JSONB, 既存Hive+Provider+get_it

---

## Task 1: supabase_flutter パッケージ追加

**Files:**
- Modify: `pubspec.yaml`

**Step**: `supabase_flutter: ^2.8.4` を dependencies に追加 → `flutter pub get`

## Task 2: Supabase匿名認証サービス

**Files:**
- Create: `lib/core/services/supabase_auth_service.dart`

**内容**: tsundoku-quest と同じパターン — `Supabase.instance.client.auth.signInAnonymously()` + ユーザーIDキャッシュ

## Task 3: SupabaseTaskRepository

**Files:**
- Create: `lib/features/guild/data/supabase_task_repository.dart`

**内容**: `ITaskRepository` 実装。`loadTasks()` → Supabase JSONB から読み取り。`saveTasks()` → JSONB upsert。

**Supabaseテーブル**: `rpg_tasks (id text PK, user_id text, data jsonb, updated_at timestamptz)`

## Task 4: SupabasePlayerRepository

**Files:**
- Create: `lib/features/shared/data/supabase_player_repository.dart`

**内容**: `IPlayerRepository` 実装。単一レコードのJSONB upsert。

**Supabaseテーブル**: `rpg_players (user_id text PK, data jsonb, updated_at timestamptz)`

## Task 5: HybridXxxRepository（DI切替）

**Files:**
- Create: `lib/features/guild/data/hybrid_task_repository.dart`
- Create: `lib/features/shared/data/hybrid_player_repository.dart`
- Modify: `lib/core/di/injection.dart` + `injection.config.dart`

**内容**: Hiveをプライマリ、Supabaseをセカンダリとするハイブリッド。Hive読み書き成功時に非同期でSupabase同期。Supabase失敗はサイレント（オフライン耐性）。

## Task 6: main.dart Supabase初期化

**Files:**
- Modify: `lib/main.dart`

**内容**: `Supabase.initialize(url: ..., anonKey: ...)` を追加。`--dart-define` で注入。

## Task 7: CI/CD対応

**Files:**
- Modify: `.github/workflows/deploy.yml`

**内容**: `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` 追加

## Task 8: Supabaseテーブル作成SQL

```sql
CREATE TABLE rpg_tasks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  data JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_rpg_tasks_user ON rpg_tasks(user_id);

CREATE TABLE rpg_players (
  user_id TEXT PRIMARY KEY,
  data JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE rpg_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE rpg_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tasks_user_access" ON rpg_tasks
  FOR ALL USING (auth.uid()::text = user_id);

CREATE POLICY "players_user_access" ON rpg_players
  FOR ALL USING (auth.uid()::text = user_id);
```
