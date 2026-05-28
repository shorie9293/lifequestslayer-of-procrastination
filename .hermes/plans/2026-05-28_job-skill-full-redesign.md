# 職業スキル再設計・完全版 — データ構造とアーキテクチャ設計書

**制定日**: 2026年5月28日（皐月二十八日）
**版**: v1.0
**神託元**: 創造主様（外部神提言含む）

---

## 一、全体像

### 現行 → 新システムの差分

| 項目 | 現行 | 新 |
|------|------|-----|
| 職業数 | 4職 | 4職（不変） |
| スキル数 | 各1個 | **各2〜4個**（浪人2、中級職4） |
| スキル発動条件 | マスター時のみ継承可 | **Lv8からスロット制**（浪人はLv10マスター） |
| 転職条件 | 浪人Lv10 | **浪人Lv10 / 中級職Lv8** |
| マスタリー | Lv10(浪人), Lv14(他) | **浪人Lv10 / 中級職Lv15** |
| 疲労 | ペナルティ | 侍スキルで逆転 |
| データ構造 | `Map<Job,int>` + `Set<Job>` | 大幅拡張 |

---

## 二、職業とスキル一覧

### 🥾 浪人（初期職）— `Job.adventurer`　⚠️ 例外: 転職解禁＝マスター＝Lv10

| Lv | スキル名 | ID | 効果 | 種別 |
|----|---------|-----|------|------|
| 1〜9 | 修練の歩み | `roninSlots` | 同時タスク枠数制限（Lv1:B枠1 → Lv2:B枠2 → Lv5:A枠1+B枠3） | パッシブ（レベル連動） |
| 10 | 日々の鍛錬 | `roninRepeatTask` | タスク上限解放（S枠1+A枠2+B枠3）+ **繰り返しタスク登録** | **マスタースキル（Lv10）** |

> **浪人のみ例外**: スキルが2段階（Lv1〜9 / Lv10）のため、Lv10でマスター扱い。
> マスター後は「日々の鍛錬」が全職業で常時パッシブ化（繰り返しタスク登録が他職でも使える）。

### ⚔️ 侍（中級職）— `Job.warrior`

| Lv | スキル名 | ID | 効果 | 種別 |
|----|---------|-----|------|------|
| 1 | 連撃 | `warriorCombo` | 一定時間内（2h）に複数タスク完了でEXP倍率上昇 | アクティブ |
| 5 | 無尽の太刀 | `warriorFatigueReverse` | 疲労ペナルティを**逆転**（疲れるほどEXP・ドロップ率UP） | アクティブ |
| 10 | 明鏡止水 | `warriorPomodoro` | ポモドーロタイマー（25分集中）。集中時間中の完了でボーナス | アクティブ |
| 15 | 武士道 | `warriorBushido` | 毎日1タスク以上完了で全職業に永続EXP微バフ | **マスター：パッシブ** |

### 🛡️ 法師（中級職）— `Job.cleric`

| Lv | スキル名 | ID | 効果 | 種別 |
|----|---------|-----|------|------|
| 1 | 輪廻の真言 | `clericRepeatAfter` | 「完了からN日後」再発生。完了起算の繰り返し機能 | アクティブ |
| 5 | 時結びの結界 | `clericSnooze` | 今日できないタスクをペナルティなしで翌日スヌーズ | アクティブ |
| 10 | 巡礼の行 | `clericStreak` | 特定タスクの連続達成日数可視化＋長期ストリークでEXP増 | アクティブ |
| 15 | 悟り | `clericEnlightenment` | 週1回：1日サボってもストリーク途切れない恩赦 | **マスター：パッシブ** |

### 🔮 陰陽師（中級職）— `Job.wizard`

| Lv | スキル名 | ID | 効果 | 種別 |
|----|---------|-----|------|------|
| 1 | 式神召喚 | `wizardSubtask` | 大タスクをサブタスクに分解 | アクティブ |
| 5 | 護符の分類 | `wizardTags` | タグ付け＋フィルタリング | アクティブ |
| 10 | 五行陣 | `wizardProject` | 関連タスクをプロジェクト化、全完了で特大報酬 | アクティブ |
| 15 | 千里眼 | `wizardOverview` | カレンダー・カンバン俯瞰ビュー全職業解放 | **マスター：パッシブ** |

---

## 三、データモデル設計

### 3.1 スキル定義（enum + extension）

```dart
/// 全職業の全スキルを一意に識別する列挙型
enum JobSkill {
  // ── 浪人 ──
  roninSlots,          // Lv1〜9: 枠数制限, Lv10: 上限解放
  roninRepeatTask,     // Lv10: 繰り返しタスク登録

  // ── 侍 ──
  warriorCombo,        // Lv1: 連撃
  warriorFatigueReverse, // Lv5: 無尽の太刀
  warriorPomodoro,     // Lv10: 明鏡止水
  warriorBushido,      // Lv15: 武士道（マスター）

  // ── 法師 ──
  clericRepeatAfter,   // Lv1: 輪廻の真言
  clericSnooze,        // Lv5: 時結びの結界
  clericStreak,        // Lv10: 巡礼の行
  clericEnlightenment, // Lv15: 悟り（マスター）

  // ── 陰陽師 ──
  wizardSubtask,       // Lv1: 式神召喚
  wizardTags,          // Lv5: 護符の分類
  wizardProject,       // Lv10: 五行陣
  wizardOverview,      // Lv15: 千里眼（マスター）
}

/// JobSkill のメタデータ
extension JobSkillMeta on JobSkill {
  /// このスキルが属する職業
  Job get job => switch (this) {
    JobSkill.roninSlots || JobSkill.roninRepeatTask => Job.adventurer,
    JobSkill.warriorCombo || JobSkill.warriorFatigueReverse ||
    JobSkill.warriorPomodoro || JobSkill.warriorBushido => Job.warrior,
    JobSkill.clericRepeatAfter || JobSkill.clericSnooze ||
    JobSkill.clericStreak || JobSkill.clericEnlightenment => Job.cleric,
    JobSkill.wizardSubtask || JobSkill.wizardTags ||
    JobSkill.wizardProject || JobSkill.wizardOverview => Job.wizard,
  };

  /// 解放に必要な職業レベル
  int get requiredLevel => switch (this) {
    JobSkill.roninSlots => 1,
    JobSkill.roninRepeatTask => 10,
    JobSkill.warriorCombo => 1,
    JobSkill.warriorFatigueReverse => 5,
    JobSkill.warriorPomodoro => 10,
    JobSkill.warriorBushido => 15,
    JobSkill.clericRepeatAfter => 1,
    JobSkill.clericSnooze => 5,
    JobSkill.clericStreak => 10,
    JobSkill.clericEnlightenment => 15,
    JobSkill.wizardSubtask => 1,
    JobSkill.wizardTags => 5,
    JobSkill.wizardProject => 10,
    JobSkill.wizardOverview => 15,
  };

  /// マスタースキル（浪人Lv10/中級職Lv15で常時パッシブ化）かどうか
  bool get isMasterSkill => this == JobSkill.roninRepeatTask || requiredLevel == 15;

  /// UI表示名
  String get displayName => switch (this) {
    JobSkill.roninSlots => '修練の歩み',
    JobSkill.roninRepeatTask => '日々の鍛錬',
    JobSkill.warriorCombo => '連撃',
    JobSkill.warriorFatigueReverse => '無尽の太刀',
    JobSkill.warriorPomodoro => '明鏡止水',
    JobSkill.warriorBushido => '武士道',
    JobSkill.clericRepeatAfter => '輪廻の真言',
    JobSkill.clericSnooze => '時結びの結界',
    JobSkill.clericStreak => '巡礼の行',
    JobSkill.clericEnlightenment => '悟り',
    JobSkill.wizardSubtask => '式神召喚',
    JobSkill.wizardTags => '護符の分類',
    JobSkill.wizardProject => '五行陣',
    JobSkill.wizardOverview => '千里眼',
  };
}
```

### 3.2 Player モデル拡張

```dart
class Player {
  // ═══ 既存フィールド（維持） ═══
  Map<Job, int> jobLevels;       // 職業ごとのレベル。初期値: {Job.adventurer: 1}
  Map<Job, int> jobExps;         // 職業ごとのEXP
  Job currentJob;                // 現在の職業
  int comboCount;                // 侍のコンボ数
  int coins;                     // 所持金
  int dailyTasksCompleted;       // 今日の討伐数
  // ... 他既存フィールド ...

  // ═══ 新規: スキルスロット ═══
  /// 装備中の他職スキル（最大2枠）
  /// Lv8〜9: 最大1枠, Lv10〜14: 最大2枠, Lv15〜: 最大2枠+マスタースキルは自動パッシブ
  List<EquippedSkill> equippedSkills;

  // ═══ 新規: 侍スキル用状態 ═══
  DateTime? pomodoroStartTime;      // ポモドーロ開始時刻
  int? pomodoroDurationMinutes;     // 集中時間（デフォルト25分）
  DateTime? lastComboTime;          // 最終コンボ時刻（2h以内判定用）
  DateTime? lastDailyComplete;      // 最終デイリー達成日（武士道バフ用）
  double warriorDailyBuff;          // 武士道による永続EXP倍率（初期1.0、毎日+0.01）

  // ═══ 新規: 法師スキル用状態 ═══
  Map<String, int> taskStreaks;           // taskId → 連続達成日数
  Map<String, DateTime> taskLastCompleted; // taskId → 最終完了日（輪廻用）
  Map<String, DateTime> snoozedTasks;      // taskId → スヌーズ後の新期限
  int streakGraceRemaining;                // 今週のストリーク恩赦残り回数（最大1）
  DateTime? lastStreakGraceReset;          // 恩赦リセット日

  // ═══ 新規: 陰陽師スキル用状態 ═══
  Map<String, Set<String>> taskTags;       // taskId → タグ一覧
  Map<String, String> taskProjects;        // taskId → プロジェクトID
  Map<String, ProjectGroup> projects;      // プロジェクト管理
}

/// 装備スキル（スロット1枠分）
class EquippedSkill {
  final JobSkill skill;
  final Job sourceJob; // どの職業から借りているか

  const EquippedSkill({required this.skill, required this.sourceJob});
}

/// プロジェクトグループ
class ProjectGroup {
  final String id;
  final String name;
  final List<String> taskIds;   // 所属タスクID一覧
  final int bonusExp;           // 全完了時の特大報酬EXP
  bool isCompleted;             // 全タスク完了済みか
}
```

### 3.3 スキル発動判定ロジック

```dart
/// プレイヤーが特定スキルを使えるか判定する
bool canUseSkill(JobSkill skill) {
  final job = skill.job;
  final requiredLv = skill.requiredLevel;

  // ① 現在の職業のスキル → Lv条件を満たせば使える
  if (currentJob == job) {
    return (jobLevels[job] ?? 1) >= requiredLv;
  }

  // ② マスタースキル（Lv15）→ その職業をマスターしていれば常時パッシブ
  if (skill.isMasterSkill) {
    return isMastered(job);
  }

  // ③ スロット装備中 → Lv条件を満たしていれば使える
  return equippedSkills.any(
    (es) => es.skill == skill && (jobLevels[es.sourceJob] ?? 1) >= requiredLv
  );
}

/// 職業をマスターしているか（浪人Lv10 / 中級職Lv15）
bool isMastered(Job job) {
  if (job == Job.adventurer) return (jobLevels[job] ?? 1) >= 10;
  return (jobLevels[job] ?? 1) >= 15;
}

/// 装備可能なスロット数
int get maxSkillSlots {
  final lv = jobLevels[currentJob] ?? 1;
  if (lv >= 10) return 2;
  if (lv >= 8) return 1;
  return 0;
}
```

### 3.4 スキル効果の実装場所（TaskCompletionService.complete() 内）

```dart
TaskCompletionResult? complete({...}) {
  // ── 侍 Lv5: 無尽の太刀（疲労逆転）─
  double fatigueMultiplier;
  if (player.canUseSkill(JobSkill.warriorFatigueReverse)) {
    // 疲労度が高いほどボーナス倍率上昇
    fatigueMultiplier = FatigueService.reverseMultiplier(player);
  } else {
    // 通常のペナルティ
    fatigueMultiplier = FatigueService.fatigueMultiplier(player);
  }

  // ── 侍 Lv1: 連撃（2h以内の連続討伐でコンボ倍率）─
  if (player.canUseSkill(JobSkill.warriorCombo)) {
    final now = DateTime.now();
    if (player.lastComboTime != null &&
        now.difference(player.lastComboTime!).inHours < 2) {
      player.comboCount++;
    } else {
      player.comboCount = 1;
    }
    player.lastComboTime = now;
    final comboBonus = player.comboCount * 10; // コンボ数×10 EXP
    expGain += comboBonus;
  }

  // ── 侍 Lv10: 明鏡止水（ポモドーロ中の討伐でボーナス）─
  if (player.canUseSkill(JobSkill.warriorPomodoro) &&
      player.pomodoroStartTime != null) {
    final elapsed = DateTime.now().difference(player.pomodoroStartTime!);
    if (elapsed.inMinutes <= (player.pomodoroDurationMinutes ?? 25)) {
      expGain = (expGain * 1.5).round();
      bonusMessages.add('🧘 明鏡止水ボーナス！ +50% EXP');
    }
  }

  // ── 侍 Lv15: 武士道（デイリーバフ）─
  if (player.canUseSkill(JobSkill.warriorBushido)) {
    expGain = (expGain * player.warriorDailyBuff).round();
  }

  // ── 浪人 Lv10: 繰り返しタスク処理 ─
  if (player.canUseSkill(JobSkill.roninRepeatTask) &&
      task.repeatInterval != RepeatInterval.none) {
    task.lastCompletedAt = DateTime.now();
    // isCompleted は false のまま（繰り返し）
  }

  // ── 法師 Lv1: 輪廻の真言（完了起算の繰り返し）─
  if (player.canUseSkill(JobSkill.clericRepeatAfter) &&
      task.repeatAfterDays != null) {
    player.taskLastCompleted[task.id] = DateTime.now();
  }

  // ── 法師 Lv10: 巡礼の行（ストリークボーナス）─
  if (player.canUseSkill(JobSkill.clericStreak)) {
    final streak = (player.taskStreaks[task.id] ?? 0) + 1;
    player.taskStreaks[task.id] = streak;
    if (streak >= 7) {
      expGain = (expGain * 1.2).round();
      bonusMessages.add('🙏 ${streak}日連続達成！巡礼ボーナス +20%');
    }
  }

  // ── 陰陽師 Lv10: 五行陣（プロジェクト全完了ボーナス）─
  if (player.canUseSkill(JobSkill.wizardProject)) {
    final projectId = player.taskProjects[task.id];
    if (projectId != null) {
      final project = player.projects[projectId];
      if (project != null && project.taskIds.every((tid) {
        // 全タスク完了チェック
        return /* ... */;
      })) {
        expGain += project.bonusExp;
        bonusMessages.add('🌟 五行陣「${project.name}」完全制覇！ +${project.bonusExp} EXP');
      }
    }
  }
}
```

---

## 四、Hiveマイグレーション計画

### 現行の PlayerAdapter (typeId=3, formatVersion=3)

```dart
// 現行
player.jobLevels = reader.readMap();  // Map<Job, int>
player.activeSkills = reader.readList().cast<Job>().toSet();
```

### 新フォーマット (formatVersion=4)

```dart
// 新規追加フィールド
if (version >= 4) {
  player.equippedSkills = _readEquippedSkills(reader);  // List<EquippedSkill>
  player.pomodoroStartTime = _readNullableDateTime(reader);
  player.lastComboTime = _readNullableDateTime(reader);
  player.warriorDailyBuff = reader.readDouble();
  player.taskStreaks = _readStringIntMap(reader);
  player.taskLastCompleted = _readStringDateTimeMap(reader);
  player.snoozedTasks = _readStringDateTimeMap(reader);
  player.streakGraceRemaining = reader.readInt();
  player.taskTags = _readStringStringSetMap(reader);
  player.taskProjects = _readStringStringMap(reader);
  player.projects = _readProjects(reader);
}
```

### 後方互換性

- v3 → v4: 新フィールドはデフォルト値で初期化
- 既存ユーザーは自動的に新システムへ移行
- `activeSkills` (Set<Job>) は非推奨化し、`equippedSkills` (List<EquippedSkill>) に移行

---

## 五、ファイル変更一覧

| ファイル | 変更内容 | 影響度 |
|---------|---------|--------|
| `lib/domain/models/player.dart` | JobSkill enum + Playerモデル拡張 + Adapter v4 | 🔴 大 |
| `lib/domain/models/skill_slot.dart` | EquippedSkill, ProjectGroup 新規モデル | 🟢 新規 |
| `lib/domain/models/task.dart` | repeatAfterDays, tags, projectId フィールド追加 | 🟡 中 |
| `lib/domain/services/fatigue_service.dart` | reverseMultiplier() 追加 | 🟡 中 |
| `lib/features/shared/domain/task_completion_service.dart` | 全スキル効果の実装 | 🔴 大 |
| `lib/features/temple/presentation/temple_screen.dart` | スキルスロットUI + 職業カード更新 | 🔴 大 |
| `lib/features/temple/presentation/dialogs/job_tutorial_dialog.dart` | 全ページ文言更新 | 🟡 中 |
| `lib/features/guild/presentation/guild_screen.dart` | 繰り返し登録UI + タグUI | 🟡 中 |
| `lib/features/player/viewmodels/player_view_model.dart` | スキルスロット操作メソッド追加 | 🟡 中 |
| `test/` 全般 | 新スキル・新モデルのテスト追加 | 🔴 大 |
| `docs/roadmap.md` | v2.1 戦神降臨の章 の進捗更新 | 🟢 小 |

---

## 六、カンバンタスク分解

### 依存グラフ

```
T1: データモデル実装（JobSkill enum + Player拡張 + Hive v4）
 ├── T2: 疲労逆転ロジック（侍Lv5）
 ├── T3: 連撃コンボロジック（侍Lv1）
 ├── T4: 浪人スキル移行（繰り返し登録）
 ├── T5: 法師スキル（輪廻・スヌーズ・巡礼）
 └── T6: 陰陽師スキル（サブタスク・タグ・プロジェクト）
      │
      ▼
T7: スキルスロットUI（寺院画面改修）
T8: 職業チュートリアル更新（文言全面刷新）
T9: 侍ポモドーロ実装（明鏡止水）
T10: 侍武士道＋法師悟り（マスターパッシブ）
T11: 陰陽師千里眼（俯瞰ビュー）
T12: 統合テスト・リグレッション確認
T13: roadmp更新・版数上げ
```
