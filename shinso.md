# 【神想】延期討伐伝 -Slayer of Procrastination-

**ステータス**: 基盤固め完了（v1.2 実装済、v1.3 構想中）
**最終更新**: 2026-04-27
**神域**: `utsushiyo/rpg-task/`
**神器**: Flutter/Dart + Provider + Hive

---

## コンセプト
タスク管理をRPGゲームとして体験するFlutterアプリ。
「冒険者ギルド」UIでタスクをクエストとして管理し、完了するたびにXPを獲得してレベルアップする。

## 現在の実装状況

### 技術スタック
- **フレームワーク**: Flutter（Dart SDK ^3.5.4）
- **状態管理**: Provider（^6.1.5+1）
- **ストレージ**: Hive（ローカル永続化）
- **フォント**: Google Fonts
- **対応プラットフォーム**: Android / Web

### アーキテクチャ
MVVM パターンを採用：
```
screens/ → viewmodels/ → repositories/ → models/
```

### 主要コンポーネント
| ファイル/フォルダ | 役割 |
|----------------|-----|
| `lib/viewmodels/GameViewModel` | プレイヤー状態・タスクロジックの中心 |
| `lib/screens/` | ホーム・ギルド・メイン画面 |
| `lib/widgets/TaskCard` | タスク表示カード |
| `lib/repositories/` | データアクセス層（Hive） |
| `lib/models/` | データモデル定義 |

### 実装済み機能
- タスクをクエストとして登録・表示（冒険者ギルド画面）
- タスク完了でXP獲得・レベルアップ
- チュートリアルオーバーレイ
- Hiveによるローカルデータ永続化
- Webビルド対応（netlify.toml 設定済み）

---

## v1.2 開発スコープ（2026-04-17 策定）

> Dev/UX/QA が実装判断できる詳細仕様。変更があれば必ずここを更新すること。

---

### 1. ストリーク（連続ログインボーナス）システム

#### Playerモデルへの追加フィールド

```dart
// player.dart に追加
int streakDays;           // 現在の連続ログイン日数（0〜∞）
DateTime? lastLoginDate;  // 最後にログインボーナスを付与した日付
int longestStreak;        // 過去最長ストリーク日数（統計用・称号解放に利用）
```

PlayerAdapter の write/read に末尾追記（`availableBytes` ガードで後方互換性を維持）。

#### ストリーク加算・リセットのトリガー

- **加算タイミング**: `loadData()` 内の `_checkAndResetMissions(isLogin: true)` が呼ばれるとき
  - `lastLoginDate` が「昨日」の日付 → `streakDays++`
  - `lastLoginDate` が「今日」の日付 → 変化なし（1日に複数回起動しても加算しない）
  - `lastLoginDate` が「2日以上前」OR `null` → `streakDays = 1`（リセット後の1日目）
  - 加算後、`lastLoginDate = DateTime.now()` に更新
  - `longestStreak = max(longestStreak, streakDays)` で更新

```
[ログイン判定フロー]
loadData()
  └─ _checkAndResetMissions(isLogin: true)
       └─ _checkAndUpdateStreak()  ← 新規追加
            ├─ lastLoginDate == null         → streakDays=1, lastLoginDate=today
            ├─ lastLoginDate == yesterday    → streakDays++, lastLoginDate=today
            ├─ lastLoginDate == today        → 何もしない
            └─ lastLoginDate < yesterday     → streakDays=1, lastLoginDate=today
            ↓（すべての分岐後）
            longestStreak = max(longestStreak, streakDays)
```

「昨日」の定義: 日付のみ比較（時刻不問）。`DateTime` の `year/month/day` で一致判定。

#### 報酬テーブル

| ストリーク日数 | 報酬 | 表示メッセージ |
|-------------|------|-------------|
| 2日目 | 金貨 +100 | 🔥 2日連続！ +100金貨 |
| 3日目 | 金貨 +200 | 🔥🔥 3日連続！ +200金貨 |
| 5日目 | 金貨 +500 + 宝石 +5 | 🔥🔥🔥 5日連続！ +500金貨 +5💎 |
| 7日目 | 金貨 +1000 + 宝石 +20 | ⚡ 1週間連続！ +1000金貨 +20💎 |
| 14日目 | 金貨 +2000 + 宝石 +50 | 👑 2週間連続！ +2000金貨 +50💎 |
| 30日目 | 金貨 +5000 + 宝石 +150 | 🌟 1ヶ月達成！ +5000金貨 +150💎 |
| 上記以外 | 金貨 +50 | 🔥 N日連続！ +50金貨 |

- ストリーク報酬は `pendingLoginBonusAmount` とは**別変数** `pendingStreakReward` として管理し、HomeScreen で既存ログインボーナスと統合表示。
- 既存ログインボーナス（金貨+50）はストリーク報酬で**置き換えではなく加算**。

---

### 2. 称号進捗バー

#### 表示場所

- **TownScreen**（`town_screen.dart`）の `_buildTitlesSection()` 内、既存の「称号装備カード」の下に追加。
- ダイアログ（`_showTitleSelectDialog`）内にも未解放称号の進捗を一覧表示する。

#### 表示内容

既存 `_checkTitles()` の条件を参照し、各称号について以下を表示する：

```
[称号カードUI]
┌─────────────────────────────────────────┐
│ 🔒 ベテラン                              │
│ 累計クエスト討伐: 67 / 100 ████████░░  67% │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ 🔒 ゴブリンスレイヤー                     │
│ Bランク討伐: 30 / 50   ██████░░░░  60%   │
└─────────────────────────────────────────┘
```

- 解放済み称号は 🏅 アイコンで「解放済み」と表示し、タップで装備切替。
- 未解放称号は 🔒 アイコンで「条件と進捗バー」を表示。
- `LinearProgressIndicator` を使用（v1.1 のミッションバッジと同コンポーネントパターン）。

#### 称号マスタデータ（Dev実装用）

現在の `_checkTitles()` から以下のように定数化して参照する：

```dart
// game_view_model.dart に追加
static const List<TitleDefinition> titleDefinitions = [
  TitleDefinition(
    id: '見習い冒険者',
    label: '累計クエスト討伐',
    threshold: 10,
    getValue: _getTotalTasksCompleted,  // ← Player参照のため関数で渡す
  ),
  TitleDefinition(id: 'ベテラン',           label: '累計クエスト討伐',   threshold: 100),
  TitleDefinition(id: 'ゴブリンスレイヤー', label: 'Bランク討伐',       threshold: 50),
  TitleDefinition(id: 'エリートハンター',   label: 'Aランク討伐',       threshold: 20),
  TitleDefinition(id: '竜殺し',            label: 'Sランク討伐',       threshold: 5),
];
```

Devは上記を `TitleDefinition` モデルクラスとして切り出すこと（`models/title_definition.dart`）。  
ゲッター `titleProgressList` を `GameViewModel` に追加し、`TownScreen` と称号ダイアログから参照する。

---

### 3. 知識クエストモード

#### データ構造

- **保存場所**: `assets/data/knowledge_quests.json`（Dart定数は可読性が低いため外部JSONを推奨）。
- `flutter pub add` 不要。`rootBundle.loadString()` で非同期ロード。
- 起動時に `GameViewModel.loadData()` 内でロードし、メモリにキャッシュ。

```json
// assets/data/knowledge_quests.json
[
  {
    "id": "q001",
    "question": "ポモドーロテクニックの1セットは何分？",
    "choices": ["15分", "25分", "45分", "60分"],
    "correct_index": 1,
    "exp_bonus_percent": 30,
    "category": "productivity"
  },
  ...
]
```

`pubspec.yaml` に `assets/data/` を追加すること。

#### モデル定義

```dart
// models/knowledge_quest.dart
class KnowledgeQuest {
  final String id;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final int expBonusPercent;   // 10〜50 の範囲で設定
  final String category;
}
```

#### 出題タイミングと画面遷移

```
[フロー]
HomeScreen: ⚔️ボタン押下
  → completeTask() を呼ぶ前に、知識クエスト抽選を実施
  → 抽選確率: 30%（毎回出題にすると煩わしいため）
  → 抽選ヒット時:
       completeTask() は呼ばず、先に KnowledgeQuestDialog を表示
       ┌────────────────────────────────┐
       │  📚 知識クエスト！             │
       │  [問題文]                      │
       │  [選択肢A] [選択肢B]           │
       │  [選択肢C] [選択肢D]           │
       │  [スキップ（EXPボーナスなし）] │
       └────────────────────────────────┘
       → 正解 or スキップ後: completeTask() 実行
  → 抽選外れ時: 従来通り即 completeTask() 実行
```

#### スキップ可否・報酬

- **スキップ: 可能**（強制は離脱率を上げるため不可）。スキップ時はボーナスなしで通常完了。
- **正解ボーナス**: 各クエストの `expBonusPercent` に基づき EXP を加算。
  - 例: 通常 100 EXP のタスク + `expBonusPercent=30` → 130 EXP
  - 計算式: `expGain = (expGain * (1 + expBonusPercent / 100)).round()`
- **不正解**: ボーナスなし（ペナルティなし）。不正解後に正解を表示してから completeTask()。
- ボーナスメッセージ: `"📚 知識クエスト正解！ +${bonusExp} EXP"` を `bonusMessages` に追加。

#### GameViewModel の変更点

```dart
// 追加フィールド
List<KnowledgeQuest> _knowledgeQuests = [];

// 追加メソッド
KnowledgeQuest? drawKnowledgeQuest() {
  if (_knowledgeQuests.isEmpty) return null;
  if (Random().nextDouble() >= 0.30) return null;  // 70%は出題なし
  _knowledgeQuests.shuffle();
  return _knowledgeQuests.first;
}
```

HomeScreen 側で `drawKnowledgeQuest()` を呼び出し、非nullなら先にダイアログ表示、その後 `completeTask()` にボーナスフラグを渡す。

---

### 4. IAPファネル改善（疲労MAX時のポップアップ）

#### 表示条件

- **疲労MAXの定義**: `player.dailyTasksCompleted >= fatigueSevereThreshold`  
  （= `dailyTasksCompleted >= 10 + todayTaskLimitOffset`、既存実装の `fatigueSevereThreshold` と一致）
- **表示トリガー**: `completeTask()` の処理完了後、`dailyTasksCompleted` が `fatigueSevereThreshold` に**到達した瞬間のみ**（= 到達後の毎回ではなく、`dailyTasksCompleted == fatigueSevereThreshold` の1回のみ）
- **再表示防止**: `_hasShownFatiguePopupToday` フラグ（bool、デイリーリセット時に `false` に戻す）を GameViewModel に追加。

```
[表示フロー（HomeScreen内）]
completeTask() 実行
  → result が non-null（成功）
  → dailyTasksCompleted == fatigueSevereThreshold && !_hasShownFatiguePopupToday
       → FatigueGemPopup を showDialog で表示
       → _hasShownFatiguePopupToday = true
```

#### ポップアップ内容

```
┌──────────────────────────────────────┐
│  🌙 今日の冒険、終了！               │
│  疲労がMAXに達しました。             │
│                                      │
│  もっと冒険を続けたいなら…          │
│  宝石で疲労を即時回復できます！      │
│                                      │
│  💎 50宝石で疲労リセット             │
│  ─────────────────────────           │
│  現在の宝石: XX 💎                   │
│                                      │
│  [回復する（50💎）]  [今日は休む]   │
└──────────────────────────────────────┘
```

- 「回復する」ボタン: `viewModel.resetFatigueWithGems()` を呼ぶ（既存実装を再利用）。
  - 成功: SnackBar「疲労がリセットされた！」を表示してダイアログを閉じる。
  - 失敗（宝石不足）: SnackBar「宝石が足りません」→ 宝石ショップへ遷移する導線を提示。
- 「今日は休む」ボタン: ダイアログを閉じるのみ。
- 宝石不足の場合、「回復する」ボタンを `Colors.grey` にしてグレーアウト（タップ時に「宝石ショップへ」遷移）。

#### 宝石消費量

- 疲労リセット: 50宝石（既存 `resetFatigueWithGems()` の料金と統一）。変更なし。

---

## 今後の開発方向

> **※ 改善方針の詳細は `docs/roadmap.md` を参照せよ。**  
> 本節は概要のみを記す。優先順位・工期・品質基準はすべて `roadmap.md` に従う。

| バージョン | 主題 | 概要 |
|-----------|------|------|
| **v1.3.0**「禍津討伐の章」 | 信頼の再興 | クリティカル3件(C1-C3)+メジャー6件(M1-M6)の討伐、UX基盤3件改善 |
| **v1.4.0**「神楽昇華の章」 | 手応えの創出 | UX改善15件以上、討伐演出、疲労可視化、朝晩通知、敵アイコン強化、テスト基盤 |
| **v2.0.0**「町興しの章」 | 愛着の創出 | 町発展可視化、キャラカスタマイズ、自動難易度推定、iOS対応、ViewModel分割 |
| **v2.1.0**「神々の連環の章」 | 大願の具現化 | 選挙ゲームとのアプリ間連携、共通ID、クロス報酬、学びの循環 |

参照先: `docs/roadmap.md`（全四神合議による最上位方針書）

---

## よく使うコマンド
```bash
flutter run          # 実行
flutter build appbundle  # Androidビルド
flutter build web    # Webビルド
flutter test         # テスト実行
flutter pub get      # 依存関係取得
```

---
*このファイルはPMエージェントが管理します。仕様変更の都度更新してください。*
