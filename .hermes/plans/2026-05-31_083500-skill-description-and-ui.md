# rpg-task スキルスロット改善計画

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** スキルスロットの「登録方法がわからない」「スキルの説明がない」というUX問題を解決する。

**Architecture:** 既存のモデル層（`JobSkill`、`EquippedSkill`）とViewModel層（`equipSkill`/`unequipSkill`）は完成済み。変更は主に①`JobSkill`に説明文を追加 ②社画面のUI改善の2点。大規模なリファクタ不要。

**Tech Stack:** Flutter / Dart、Provider、Hive（永続化済み）

---

## 四神分析

### 思兼神（PM）視点
- **問題**: スキルスロットは表示されているが、ユーザーが「何をどうすればスキルが使えるか」がわからない
- **根本原因**: ①スキルに効果説明がない ②他の職業のスキルを装備する仕組みが直感的でない ③空きスロットに「+」ボタンがあるが、条件を満たしていなければ何も出ない
- **優先度**: ユーザーの「わからない」を直接解決する改善。v2.0スキルツリーの前段階

### 天目一箇神（Dev）視点
- **既存コード**: `player.dart` に `JobSkill` enum（14スキル）、`skill_slot.dart` に `EquippedSkill`、`temple_screen.dart` にUI完成済み
- **変更範囲**: `player.dart`（description追加）、`temple_screen.dart`（説明表示＋ガイダンス追加）
- **リスク**: 低。Hiveマイグレーション不要（enumのフィールド追加はシリアライズに影響なし）

### 天宇受賣命（UX）視点
- **現状**: スキル名だけ（「連撃の構え」等）で効果が不明。空きスロットの「+」を押しても候補が出ない場合がある
- **改善案**: ①各スキル名の下に説明文を表示 ②スロットに「他の職業のLv到達スキルを装備可能」というガイド ③スキル説明はタップで展開するトグル式

### 月読命（QA）視点
- **試験方針**: 既存の `skill_slot_test.dart`、`wizard_skills_test.dart`、`skill_system_integration_test.dart` に追加
- **確認事項**: description表示、スキル装備フロー、ロック状態のスキルに説明が見えること

---

## タスク一覧

### Task 1: JobSkill に description フィールドを追加

**Objective:** 全14スキルに効果説明文を追加する

**Files:**
- Modify: `lib/domain/models/player.dart` — `JobSkillMeta` extension

**実装内容:**

`JobSkillMeta` extension に `description` getter を追加:

```dart
String get description {
  switch (this) {
    // Ronin
    case JobSkill.roninSlots:
      return 'クエストランクと枠数が拡大。S/A/Bランクの上限が増える';
    case JobSkill.roninRepeatTask:
      return '完了済みクエストを「繰り返し」として再発行可能に';
    // Warrior
    case JobSkill.warriorCombo:
      return '連続達成でEXPボーナス。コンボ数が多いほど報酬が増える';
    case JobSkill.warriorFatigueReverse:
      return '疲労度が高いほどEXP倍率が上昇。逆境が強さに変わる';
    case JobSkill.warriorPomodoro:
      return 'ポモドーロタイマー連動。集中時間に応じてEXPボーナス';
    case JobSkill.warriorBushido:
      return '毎日1つクエストを完了するだけでバフが蓄積。継続が力に';
    // Cleric
    case JobSkill.clericRepeatAfter:
      return '完了後、指定日数で自動的にクエストを再発行';
    case JobSkill.clericSnooze:
      return 'クエストをスヌーズ（後回し）可能。猶予を与えられる';
    case JobSkill.clericStreak:
      return 'タスクごとの連続完了を記録。ストリークで報酬UP';
    case JobSkill.clericEnlightenment:
      return '週1回、ストリークを守る猶予。中断しても連続記録が消えない';
    // Wizard
    case JobSkill.wizardSubtask:
      return 'クエストをサブクエスト（小タスク）に分割可能に';
    case JobSkill.wizardTags:
      return 'クエストに札（タグ）を付けて整理・検索';
    case JobSkill.wizardProject:
      return '複数クエストをプロジェクトとしてまとめ、全達成でボーナス';
    case JobSkill.wizardOverview:
      return 'プロジェクト全体を俯瞰し、進捗を一覧表示';
  }
}
```

**検証:**
```bash
cd /home/horie/projects/takamagahara/utsushiyo/rpg-task
flutter analyze lib/domain/models/player.dart
```

**Commit:**
```bash
git add lib/domain/models/player.dart
git commit -m "feat: add description field to all 14 JobSkill entries"
```

---

### Task 2: スキル説明を社画面の「現在の職業スキル」に表示

**Objective:** 現在の職業スキル一覧に各スキルの説明文を表示する

**Files:**
- Modify: `lib/features/temple/presentation/temple_screen.dart` — `_buildCurrentJobSkillsSection`

**実装内容:**

`_buildCurrentJobSkillsSection` 内のスキル行（line 328-372）を修正:
- スキル名の下に `skill.description` を `TextStyle(color: Colors.white54, fontSize: 11)` で表示
- 未解放スキルにも説明を薄く表示（locked状態でも「何ができるか」を知らせる）

```dart
// 既存のスキル行の Expanded の中身を以下に変更:
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        skill.displayName,
        style: TextStyle(
          color: isUnlocked ? Colors.white : Colors.grey,
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        skill.description,
        style: TextStyle(
          color: isUnlocked ? Colors.white54 : Colors.grey.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    ],
  ),
),
```

**検証:**
```bash
flutter analyze lib/features/temple/presentation/temple_screen.dart
flutter test test/domain/models/skill_slot_test.dart
```

**Commit:**
```bash
git add lib/features/temple/presentation/temple_screen.dart
git commit -m "feat: show skill descriptions in temple current job skills list"
```

---

### Task 3: スキル装備ポップアップに説明文を追加

**Objective:** 空きスロットの「+」ポップアップメニューにスキル説明を表示する

**Files:**
- Modify: `lib/features/temple/presentation/temple_screen.dart` — `_buildSlotRow` の `PopupMenuButton`

**実装内容:**

`PopupMenuItem`（line 280-286）を2行表示に変更:

```dart
PopupMenuItem<JobSkill>(
  value: skill,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "${_jobDisplayName(skill.job)}・${skill.displayName}",
        style: const TextStyle(fontSize: 13),
      ),
      Text(
        skill.description,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  ),
),
```

**検証:**
```bash
flutter analyze lib/features/temple/presentation/temple_screen.dart
```

**Commit:**
```bash
git add lib/features/temple/presentation/temple_screen.dart
git commit -m "feat: show skill descriptions in equip popup menu"
```

---

### Task 4: スキルスロットにガイダンステキストを追加

**Objective:** スキルスロットセクションに「他の職業を育てるとスキルを装備できる」説明を追加

**Files:**
- Modify: `lib/features/temple/presentation/temple_screen.dart` — `_buildSkillSlotSection`

**実装内容:**

スロット一覧の下にガイダンスを追加（line 170付近、`...List.generate` の後）:

```dart
const SizedBox(height: 8),
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      const Icon(Icons.info_outline, size: 14, color: Colors.white38),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          '他の職業を育てると、そのスキルをスロットに装備できます。'
          'Lv到達で解放されたスキルが候補に表示されます。',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ),
    ],
  ),
),
```

**検証:**
```bash
flutter analyze lib/features/temple/presentation/temple_screen.dart
```

**Commit:**
```bash
git add lib/features/temple/presentation/temple_screen.dart
git commit -m "feat: add guidance text explaining cross-job skill inheritance"
```

---

### Task 5: 試験追加＋全体検証

**Objective:** description の表示を含む試験を追加し、全試験が通ることを確認

**Files:**
- Modify: `test/domain/models/skill_slot_test.dart` — description のテスト追加

**実装内容:**

```dart
test('JobSkill.description returns non-empty string for all skills', () {
  for (final skill in JobSkill.values) {
    expect(skill.description, isNotEmpty);
    expect(skill.description.length, greaterThan(5));
  }
});

test('JobSkill.displayName and description are different', () {
  for (final skill in JobSkill.values) {
    expect(skill.description, isNot(equals(skill.displayName)));
  }
});
```

**検証:**
```bash
cd /home/horie/projects/takamagahara/utsushiyo/rpg-task
flutter pub get && flutter test --no-pub
flutter analyze
```

**Commit:**
```bash
git add test/domain/models/skill_slot_test.dart
git commit -m "test: add JobSkill description tests for all 14 skills"
```

---

## 変更ファイルまとめ

| ファイル | 変更内容 |
|---------|---------|
| `lib/domain/models/player.dart` | `JobSkillMeta` に `description` getter 追加 |
| `lib/features/temple/presentation/temple_screen.dart` | スキル説明表示、ポップアップ改善、ガイダンス追加 |
| `test/domain/models/skill_slot_test.dart` | description テスト追加 |

## 範囲外（将来のスキルツリーで対応）

- スキルポイントの導入
- ツリー状のスキル解放UI
- スキル効果の実際のゲームメカニクスへの反映強化
