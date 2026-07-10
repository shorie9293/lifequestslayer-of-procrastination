# 八百万トークン最適化計画 — fable超え

> **For Hermes:** 天照大神として、この計画を Phase ごとに実行せよ。
> 各 Phase 完了時に創造主に奏上し、確認を得てから次 Phase に進むこと。

**Goal:** 7施策により Hermes Agent のトークン消費を fable 比 1/3 以下に削減しつつ、性能を維持・向上させる。

**Architecture:** 4 Phase 構成。Phase 1（即効config変更）→ Phase 2（キャッシュ検証）→ Phase 3（スキル軽量化）→ Phase 4（高度ツール制御）。各 Phase は独立して効果測定可能。

**Tech Stack:** Hermes config.yaml, Hermes Skills (SKILL.md, YAML frontmatter), OpenRouter API

**前提:**
- 現在のモデル: `deepseek/deepseek-v4-pro` (128K context)
- 現在のツール数: 30+（全有効）
- 現在のスキルカテゴリ: 30（サブスキル含め70+）
- 圧縮しきい値: 0.5（50%）, 目標: 0.2（20%）
- OpenRouter レスポンスキャッシュ: 有効（TTL 300s）
- Prompt caching TTL: 5m

---

## Phase 1: 即効性 config 最適化（施策1, 4）

**目標:** 1ターンあたりのツール定義トークンを 15K→2K に削減（87%減）。
コンパクション早期化で長セッションのトークン爆発を防止。

### Task 1.1: コーディング用ツールセットの最小化

**Objective:** 不要ツールを無効化し、API に送るツール定義を最小化する。

**Files:**
- Modify: `~/.hermes/config.yaml`

**Step 1: 現在のツールセット状態を記録**

```bash
cat ~/.hermes/config.yaml | grep -A 2 "disabled_toolsets"
```

**Step 2: コーディング以外のツールを無効化**

以下のツールセットを disabled_toolsets に追加する：
```yaml
disabled_toolsets:
  - web           # コーディング時は不要（調査時に都度有効化）
  - browser       # 同上
  - vision        # 画像分析はコーディングに関係ない
  - image_gen     # 同上
  - tts           # 同上
  - video         # 同上
  - messaging     # Discord連携はGatewayに任せる
  - session_search # セッション検索は必要な時だけ
  - clarify       # 自律タスクではclarify不要
  - cronjob       # cron管理は別セッションで
  - kanban        # 同上
  - todo          # 計画はplanスキルで管理
  - skills        # スキル管理は必要な時だけ
```

**Step 3: 設定を適用**

```bash
hermes config set agent.disabled_toolsets "[web,browser,vision,image_gen,tts,video,messaging,session_search,clarify,cronjob,kanban,todo,skills]"
```

**Step 4: 検証**

新しいセッションで `/reset` し、利用可能ツールが以下に絞られていることを確認：
- terminal
- file (read_file, write_file, patch, search_files)
- delegation (delegate_task)
- code_execution (execute_code)
- memory

**Step 5: 巻き戻し手順の確保**

元の設定をバックアップ：
```bash
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.backup-20260707
```

**リスク:** 調査タスクで web/browser が必要になった場合、都度再有効化が必要。
**対策:** 調査用のプロファイルを作成し、調査タスクはそのプロファイルで実行する。
（Phase 4 で自動切り替えを検討）

---

### Task 1.2: コンパクションしきい値の最適化

**Objective:** コンテキストが 128K の 35% に達した時点で 15% に圧縮する。
（現在: 50% → 20%）

**Files:**
- Modify: `~/.hermes/config.yaml`

**Step 1: 設定変更**

```bash
hermes config set compression.threshold 0.35
hermes config set compression.target_ratio 0.15
```

**Step 2: 検証**

```bash
hermes config get compression
# 期待出力:
# compression.threshold: 0.35
# compression.target_ratio: 0.15
```

**リスク:** 圧縮が早すぎると重要な会話コンテキストが失われる可能性。
**対策:** `protect_last_n: 20` は維持。圧縮モデルは無料モデル（nemotron-3-super-120b）を使用中で、要約品質に注意。

---

### Phase 1 完了チェックリスト

- [ ] disabled_toolsets が正しく設定されている
- [ ] `/reset` 後にツール一覧が最小化されている
- [ ] `compression.threshold = 0.35`
- [ ] `compression.target_ratio = 0.15`
- [ ] バックアップが存在する (`~/.hermes/config.yaml.backup-20260707`)

---

## Phase 2: キャッシュ効率の検証と改善（施策5）

**目標:** OpenRouter 経由で prompt-cache が実際に効いているか計測し、効率を最大化する。

### Task 2.1: キャッシュヒット率の計測

**Objective:** 現在のセッションでキャッシュが有効に機能しているか確認する。

**Step 1: テスト用セッションでキャッシュ挙動を観察**

```bash
# 新規セッションを開始
hermes reset

# 単純な質問を2回連続で投げ、APIレスポンスヘッダーを比較
# OpenRouter のレスポンスに x-openrouter-cache: HIT/MISS が含まれるか確認
```

**Step 2: OpenRouter ダッシュボードでキャッシュ統計を確認**

https://openrouter.ai/activity でキャッシュヒット率を確認。

**Step 3: 結果の記録**

- キャッシュヒット率が 70% 未満 → 設定見直し（Task 2.2）
- キャッシュヒット率が 70% 以上 → 現状維持、Phase 3 へ

### Task 2.2: キャッシュ設定の最適化（ヒット率が低い場合）

**Objective:** prompt caching TTL と OpenRouter キャッシュ設定を調整。

**Step 1: TTL 延長**

```bash
hermes config set prompt_caching.cache_ttl 10m
hermes config set openrouter.response_cache_ttl 600
```

**Step 2: 再計測**

Task 2.1 を再実行し、改善を確認。

**リスク:** OpenRouter のキャッシュはサーバー側の実装に依存。設定が効かない可能性あり。
**対策:** 効かない場合は Hermes の Issue として報告。Phase 4 のツール隠蔽で代替。

---

### Phase 2 完了チェックリスト

- [ ] キャッシュヒット率を計測した
- [ ] ヒット率 < 70% の場合、TTL を調整した
- [ ] 結果を神書に記録した

---

## Phase 3: スキル体系の軽量化（施策2, 3, 6）

**目標:** セッション開始時にロードされるスキル情報を最小化し、
available_skills リストの肥大化を抑制する。

### Task 3.1: yaoyorozu-bootstrap スキルの軽量化

**Objective:** 現在 ~160 行のスキルを、コアの掟のみに絞り 80 行以下にする。
詳細な事例・手順は references/ に分離する。

**Files:**
- Modify: `~/.hermes/skills/yaoyorozu/yaoyorozu-bootstrap/SKILL.md`
- Create: `~/.hermes/skills/yaoyorozu/yaoyorozu-bootstrap/references/evidence-rule-examples.md`
- Create: `~/.hermes/skills/yaoyorozu/yaoyorozu-bootstrap/references/skill-1percent-examples.md`

**Step 1: 現状の行数確認**

```bash
wc -l ~/.hermes/skills/yaoyorozu/yaoyorozu-bootstrap/SKILL.md
```

**Step 2: スキルを再構成**

現在の構造を以下のように変更：
```markdown
---
name: yaoyorozu-bootstrap
description: "八百万起動の掟。1%ルール・証拠強制・神書参照の鉄則（コア）。"
version: 2.0.0
---

# 八百万起動の掟（コア）

## 第零条：1%ルール
任務に関連スキルが1%でも該当 → `skills_list()` → `skill_view()` でロード。
詳細: `skill_view(name="yaoyorozu-bootstrap", file_path="references/skill-1percent-examples.md")`

## 第一条：神書参照
タスク前に `query_zettelkasten.py <keywords>` を実行。

## 第二条：証拠強制
「たぶん動く」禁止。証拠（ls -la, curl HTTP code, test output）を提示。
禁止文言と証拠例: `references/evidence-rule-examples.md`

## 第三条：創造主への忠誠
1. 創造主の指示は絶対 2. 即決即行 3. CI常時グリーン 4. const/lint最適化 5. 推測禁止・診断せよ

## 第四条：自己改善
複雑タスク成功 → skill_manage(create)。エラー克服 → skill_manage(patch)。
スキル肥大化（300行超）→ references/ に分離。

## 最終確認
- [ ] skills_list() 実行
- [ ] 関連スキルを skill_view()
- [ ] 神書検索
```

**Step 3: 分離した reference ファイルを作成**

`references/evidence-rule-examples.md`:
```markdown
# 証拠強制の掟 — 具体例

## 禁止文言
- 「動作確認しました」
- 「問題なく動いています」
- 「修正しました」
- 「デプロイしました」

## 必須証拠
| 作業 | 証拠 |
|------|------|
| ファイル作成 | `ls -la <path>` |
| テスト実行 | `pytest` の実際の出力 |
| HTTP疎通 | `curl -w "%{http_code}"` |
| ビルド成功 | `flutter build` 最終行 + exit code |
| Git操作 | `git log --oneline -1` |
```

**Step 4: 検証**

```bash
wc -l ~/.hermes/skills/yaoyorozu/yaoyorozu-bootstrap/SKILL.md
# 期待: 80 行以下
```

---

### Task 3.2: takamagahara-shinsho スキルの更なる圧縮

**Objective:** すでに圧縮済み（v1.26.0 で82%圧縮）だが、Cronジョブが毎回ロードするため、
参照セクションをさらに削減する。

**Files:**
- Modify: `~/.hermes/skills/takamagahara-shinsho/SKILL.md`

**Step 1: 現状の行数とサイズを確認**

```bash
wc -l ~/.hermes/skills/takamagahara-shinsho/SKILL.md
du -h ~/.hermes/skills/takamagahara-shinsho/SKILL.md
```

**Step 2: 削減対象の特定**

Cronジョブが実際に参照するセクションのみを残し、他を references/ に移動：
- 残す: 神書検索コマンド、Cron体系概要（1行リンク）、緊急連絡先
- 移動: 詳細な神書一覧、運用リズム表、全Cronジョブ詳細

**Step 3: パッチ適用**

```bash
# オリジナルをバックアップ
cp ~/.hermes/skills/takamagahara-shinsho/SKILL.md ~/.hermes/skills/takamagahara-shinsho/SKILL.md.backup
```

**Step 4: 検証**

```bash
du -h ~/.hermes/skills/takamagahara-shinsho/SKILL.md
# 期待: 20KB以下
```

---

### Task 3.3: スキルロード選択性の強化（神書連動）

**Objective:** `skills_list()` の全件確認を避け、タスクキーワードに基づいて
必要なスキルのみを `skill_view()` するよう、yaoyorozu-bootstrap の指示を修正。

**Files:**
- Modify: `~/.hermes/skills/yaoyorozu/yaoyorozu-bootstrap/SKILL.md`

**変更内容:**
```markdown
## 第零条：1%ルール（改訂v2）

**手順:**
1. タスク内容からキーワードを抽出（例: "Flutterデプロイ" → flutter, deploy, Play Store）
2. スキル一覧から description のキーワードマッチで候補を絞る
3. 該当スキルのみ `skill_view()` でロード
4. **全スキルを手動確認する必要なし。キーワードマッチで十分。**
```

**Step 1: パッチ適用**

Step 2: 検証 — 次のタスクで実際に機能するか確認。

---

### Phase 3 完了チェックリスト

- [ ] yaoyorozu-bootstrap が 80 行以下
- [ ] takamagahara-shinsho が 20KB 以下
- [ ] references/ ファイルが作成されている
- [ ] スキルロード選択性の指示が反映されている
- [ ] バックアップが存在する

---

## Phase 4: 高度ツール動的制御（施策7）

**目標:** タスクタイプに応じてツールセットを動的に切り替える仕組みを実装する。
fable の「最小限ツール」の設計思想を Hermes に移植。

### Task 4.1: タスク別ツールプロファイルの設計

**Objective:** コーディング/調査/デプロイ の3モードで最適なツールセットを定義する。

**Files:**
- Create: `~/.hermes/skills/yaoyorozu/tool-profiles/SKILL.md`
- Create: `~/.hermes/skills/yaoyorozu/tool-profiles/references/coding-profile.md`
- Create: `~/.hermes/skills/yaoyorozu/tool-profiles/references/research-profile.md`
- Create: `~/.hermes/skills/yaoyorozu/tool-profiles/references/deploy-profile.md`

**Step 1: コーディングプロファイル定義**

```markdown
# コーディング用ツールプロファイル
# 残す: terminal, file, patch, delegate_task, execute_code, memory
# 無効化: web, browser, vision, image_gen, tts, video, messaging,
#          session_search, clarify, cronjob, kanban, todo, skills

有効化コマンド:
hermes config set agent.disabled_toolsets "[web,browser,vision,image_gen,tts,video,messaging,session_search,clarify,cronjob,kanban,todo,skills]"
```

**Step 2: 調査プロファイル定義**

```markdown
# 調査用ツールプロファイル
# 残す: web, browser, web_extract, terminal, file, memory, clarify, session_search
# 無効化: image_gen, tts, video, cronjob, kanban, delegation, code_execution

有効化コマンド:
hermes config set agent.disabled_toolsets "[image_gen,tts,video,cronjob,kanban,delegation,code_execution]"
```

**Step 3: デプロイプロファイル定義**

```markdown
# デプロイ用ツールプロファイル
# 残す: terminal, file, patch, delegation, cronjob, messaging, memory
# 無効化: web, browser, vision, image_gen, tts, video, session_search, clarify, todo, skills, code_execution
```

---

### Task 4.2: ツールプロファイル自動切り替えスキルの作成

**Objective:** タスク開始時に天照がタスクタイプを判定し、適切なプロファイルを自動適用する。

**Files:**
- Create: `~/.hermes/skills/yaoyorozu/tool-profiles/SKILL.md`

**Step 1: スキル本体**

```markdown
---
name: tool-profiles
description: "タスクタイプに応じて最適なツールセットを自動選択する。コーディング/調査/デプロイの3モード。"
version: 1.0.0
---

# ツールプロファイル自動選択

## トリガー条件

タスク内容に以下のキーワードが含まれる場合、対応プロファイルを適用:

| キーワード | プロファイル | 残すツール |
|-----------|------------|-----------|
| コード/実装/修正/bug/fix/refactor/build/test | coding | terminal, file, patch, delegate_task, execute_code |
| 調査/検索/research/調べて/教えて/情報 | research | web, browser, web_extract, terminal, file |
| デプロイ/deploy/リリース/release/降臨/Play Store | deploy | terminal, file, delegation, cronjob, messaging |

## 手順

1. タスク内容からキーワードを抽出
2. 該当プロファイルを特定
3. `hermes config set agent.disabled_toolsets "[...]"` を実行
4. `/reset` を促す（ツール変更は要セッション再起動）
5. プロファイル変更を奏上
```

---

### Task 4.3: Hermes改造の検討（tool-profiles が不十分な場合）

**Objective:** 上記の config ベースのアプローチで十分な効果が得られない場合、
Hermes 本体にツール動的切り替えの PR を送る準備をする。

**Step 1: 効果測定**

Phase 4.1-4.2 の施策適用後、1週間のトークン消費を追跡し、fable 比 1/3 を下回るか検証。

**Step 2: 不足があれば Hermes Issue/PR を作成**

```bash
# Hermes のソースコードを確認
ls ~/.hermes/hermes-agent/tools/
```

ツールの動的ロードをサポートする改造の feasibility を調査。

---

### Phase 4 完了チェックリスト

- [ ] 3つのツールプロファイル定義が完了
- [ ] tool-profiles スキルが作成・動作確認済み
- [ ] タスクタイプ自動判定が機能している
- [ ] トークン消費削減率を測定（目標: fable 比 1/3 以下）

---

## 全体完了チェックリスト

- [ ] Phase 1: ツールセット最小化 + コンパクション最適化
- [ ] Phase 2: キャッシュ効率検証・改善
- [ ] Phase 3: スキル軽量化（bootstrap + shinsho + 選択性強化）
- [ ] Phase 4: ツール動的制御（プロファイル + 自動切り替え）
- [ ] 神書に新ノート「トークン最適化の掟」を追加
- [ ] 最終奏上: Before/After のトークン消費比較

---

## リスク一覧

| リスク | 影響 | 対策 |
|--------|------|------|
| ツール不足でタスク失敗 | 高 | 都度再有効化 + 調査用プロファイル |
| コンパクションで重要コンテキスト喪失 | 中 | protect_last_n維持 + protect_first_n追加 |
| OpenRouterキャッシュ非対応 | 中 | Phase 4のツール隠蔽で代替 |
| スキル軽量化で情報不足 | 低 | references/ に全情報保持 |
| Hermes改造が複雑すぎる | 中 | config ベースで妥協可能 |
