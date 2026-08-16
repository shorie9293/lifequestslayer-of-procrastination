# Hive → Isar 移行評価報告書

**制定日**: 令和八年葉月十六日（2026年8月16日）
**制定神**: 八百万（やおよろず）— 天目一箇神（Dev）視点
**対象**: `utsushiyo/rpg-task` 技術リファクタリング計画 §五「Hive → Isar 移行評価」
**参照**: `docs/roadmap.md` 五「技術的負債の返済計画」、`shinsho/zettelkasten/03_現世カタログ/📁_rpg-task/08_rpg-task_v2_技術リファクタ.md`

---

## 一、評価の背景

本項目は roadmap §五 の「Hive → Isar 移行評価」として計画された。2026年4月時点では、
Isar が「型安全クエリ・Isolate対応・複合インデックス」において Hive より優れるとされ、
移行が技術的負債返済の一環として位置づけられていた。

しかし、**2026年8月現在、Flutter ローカルDBエコシステムの状況は当初前提から大きく変化している**。
本報告は、移行の前提そのものを再検証した結果を記す。

---

## 二、エコシステム調査結果（2026年8月時点）

### 2.1 Isar（移行先候補）— 事実上メンテナンス停止

- 原作者（Simon Leier、Hive の作者でもある）が沈黙。コミット間隔が長期化し、公式チャネルへの応答もなし。
- **公式 v4 は安定版に到達していない**（string ID・動的プロパティ等の目玉機能は v4 で未完のまま）。
- 現存するのは `isar-community` フォークのみ（**v3 のバグ修正に特化**、機能追加なし）。

> 参照: 「The Flutter Local Database Landscape in 2026」— *"Avoid Isar and original Hive for new projects.
> Both stalled. Community forks exist, but a fork is a liability you take on, not a feature you get."*
> （Isar と旧 Hive は新規プロジェクトでは避けよ。両者とも停滞。フォークは機能ではなく負債である）

### 2.2 Hive（現行）— こちらもオリジナルは停滞、ただし後継あり

- オリジナル `hive` / `hive_flutter` も原作者によるメンテは停止（rpg-task が依存する `hive: ^2.2.3` を含む）。
- **ただし `hive_ce`（Hive Community Edition）が活発に後継メンテ**：
  - 最新 `2.19.3`（2026年2月公開）、月間約70万DL、verified publisher（iodesignteam.com）
  - Hive v2 の「精神的後継」で、**API はほぼドロップイン互換**（import 書き換え＋バージョン更新で移行可能）
  - 追加機能（Isar の backend 統合オプション等）あり

### 2.3 コミュニティ推奨（2026年）

| 選択肢 | モデル | メンテ状況(2026) | Web | 推奨 |
|--------|--------|------------------|-----|------|
| Drift | SQL/ORM | 健全 | ✅ | リレーショナル＋オフライン優先で最有力 |
| ObjectBox | NoSQLオブジェクト | 健全（商用） | ❌ | 同期型NoSQL・端末内AI |
| **Isar** | NoSQL | ⚠️ コミュニティフォークのみ | ⚠️ | プロトタイプ・リスク許容時のみ |
| **Hive CE** | キーバリュー | ⚠️ CE（活発） | ✅ | 簡易キーバリュー |

---

## 三、rpg-task の現状利用状況（Hive 依存面）

| 種別 | 内容 |
|------|------|
| Hive Box | 約11個：`player`(+`player_backup`) / `tasks`(+`tasksBox_backup`) / `settings` / `tutorial` / `reflections` / `town` / `random_event` / `cross_app_rewards` / `cross_app_settings` / `notification` / `pending_gems`（＋ `takamagahara_identity` の `universal_profile`） |
| アダプタ | 9個：Task(0)/TaskStatus(1)/QuestionRank(2)/Player(3)/Job(4)/RepeatInterval(5)/SubTask(6)/Reflection(7)/JobSkill(10) |
| 利用ファイル | 18ファイル（リポジトリ・サービス・ViewModel に分散） |
| クラウド同期 | Supabase ハイブリッド同期（`HybridTaskRepository` / `HybridPlayerRepository`）**導入済み** |

### 利用特性の分析

- データ規模は**極小**（単一ユーザー。タスク数十〜数百件、プレイヤー1件、設定/チュートリアル各少数キー）。
- アクセスパターンは**ほぼキーバリュー**（`box.get` / `box.put` / `box.clear`）。複合クエリ・インデックス・JOIN は実質不要。
- Isar の売り（型安全クエリ・Isolate・複合インデックス）は**現状のユースケースでは過剰**。

---

## 四、評価結論

### 結論：**Isar への移行は非推奨（やらない）**

理由は以下の通り：

1. **移行先の消滅** — Isar はメンテナンス停止、v4 は安定版未達。型安全クエリ等の利点を得るために、
   維持されていないライブラリへ移行するのは「負債の返済」ではなく「負債の先送り（悪化）」である。
2. **リターンが薄い** — 現アーキテクチャ（単一ユーザー・キーバリュー主体・Supabase 同期済み）では、
   Isar の型安全クエリ・複合インデックス・Isolate の恩恵がほぼ無い。
3. **コストが高い** — 18ファイル・9アダプタ・10+Box の書き換え＋マイグレーション検証を、
   上記1・2の条件下で行う正当性がない。

---

## 五、推奨方針（代替案）

### 短期的（推奨）：Hive → Hive CE（`hive_ce`）へのドロップイン移行

- 旧 Hive の後継で活発メンテ。API 互換性が高く、**import 書き換え＋pubspec バージョン更新**で対応可能。
- 「メンテナンス停止した旧 Hive に依存し続ける」リスクを、低コストで解消できる。
- 工数目安：0.5〜1日（アダプタは `hive_ce_generator` で再生成、`Hive.initFlutter` → `Hive.initFlutter` 等の微修正）。

### 中長期的（データ規模・要件が成長したら）：Drift への移行を検討

- Drift は健全にメンテされ、リレーショナルな問い合わせ・統計に強い。
- 例：「振り返りの杜」の成長記録の集計・傾向分析など、**SQL 的な問い合わせが必要になった時点**で価値が出る。
- ただし SQL・スキーマ設計・DAO 書き換えと移行コストは大。現時点では時期尚早。

### 現状維持（Hive のまま）も一応の選択肢だが非推奨

- Hive は「動いてはいる」がメンテ停止。バグ修正・新OS対応が入らないリスクを内包。

---

## 六、技術リファクタリング計画 §五 の再評価（全体）

| 項目 | 状態 | 評価 |
|------|------|------|
| GameViewModel 5分割 | ✅ **完了済み** | `game_view_model.dart` は1899行→342行のファサードに縮小。TaskVM/PlayerVM/ShopVM/SettingsVM/ThemeVM（＋TownVM/BattleVM）へ委譲 |
| DI導入（get_it+injectable） | ✅ **完了済み** | `lib/core/di/injection.dart` ＋ `injection.config.dart`。二重構造は `e85afb9` で解消済み |
| Hive→Isar移行評価 | ✅ **評価完了（移行は非推奨）** | 本報告の通り。代替として Hive→Hive CE を推奨 |
| Feature Flag システム | 🔴 未着手 | 別タスク（v1.4 から前倒しとされていたが未実施） |
| イベントバス導入 | 🔴 未着手 | 別タスク（ViewModel 間疎結合化） |

---

## 七、関連

- `docs/roadmap.md` 五「技術的負債の返済計画」
- `shinsho/zettelkasten/03_現世カタログ/📁_rpg-task/08_rpg-task_v2_技術リファクタ.md`
- `shinsho/zettelkasten/02_神器と基盤/16_コード適応_依存性注入.md`（DIパターン）
