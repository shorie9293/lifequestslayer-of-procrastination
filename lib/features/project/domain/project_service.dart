// 計画の陣（プロジェクト機能）— 純粋ロジック層
//
// Flutter widget 非依存。Player/Task/ProjectGroup のみを扱う。
// コード適応神書 原則: 依存性注入可能な純粋関数群。

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// プロジェクト新規作成時の検証エラー種別。
enum ProjectValidationError { empty, tooLong, duplicate }

/// プロジェクトの進捗スナップショット。
class ProjectProgress {
  final String name;
  final int bonusExp;
  final int totalTasks;
  final int completedTasks;

  const ProjectProgress({
    required this.name,
    required this.bonusExp,
    required this.totalTasks,
    required this.completedTasks,
  });

  /// 進捗率（0.0〜1.0）。totalTasks が 0 のときは 0 除算を避けて 0.0。
  double get ratio =>
      totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

  /// 全所属クエスト完了で true（所属 0 件は既存ボーナス判定 `.every` と同様 true）。
  bool get isComplete => completedTasks >= totalTasks;

  /// '2 / 5' 形式の表示ラベル。
  String get progressLabel => '$completedTasks / $totalTasks';
}

/// 現在職業のスキル情報（一覧表示用）。
class JobSkillInfo {
  final JobSkill skill;
  final int requiredLevel;
  final bool isUnlocked;

  const JobSkillInfo({
    required this.skill,
    required this.requiredLevel,
    required this.isUnlocked,
  });
}

/// 計画の陣の純粋ドメインサービス。
class ProjectService {
  ProjectService._();

  /// プロジェクト名の最大文字数。
  static const int maxNameLength = 20;

  /// 全角スペース→半角、連続空白圧縮、前後 trim。
  static String normalize(String raw) {
    final halfWidth = raw.replaceAll('\u3000', ' ');
    return halfWidth.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ');
  }

  /// 新規作成名の検証。OK なら null。
  /// 重複判定は normalize 後の名前比較。
  static ProjectValidationError? validateNew(
    List<ProjectGroup> existing,
    String raw,
  ) {
    final name = normalize(raw);
    if (name.isEmpty) return ProjectValidationError.empty;
    if (name.length > maxNameLength) return ProjectValidationError.tooLong;
    final normalizedExisting = existing.map((g) => normalize(g.name)).toSet();
    if (normalizedExisting.contains(name)) {
      return ProjectValidationError.duplicate;
    }
    return null;
  }

  /// プロジェクト一覧（宣言順・非破壊）。返却リスト自体は新規（自由に操作可）。
  static List<ProjectGroup> listProjects(Player p) => List.of(p.projects);

  /// プロジェクトに所属するクエスト一覧（taskProjects 逆引き）。
  static List<Task> tasksOf(Player p, String projectName, List<Task> tasks) {
    return tasks
        .where((t) => p.taskProjects[t.id] == projectName)
        .toList(growable: false);
  }

  /// プロジェクトの進捗。存在しない taskId は分母に数えない。
  static ProjectProgress progressFor(
    Player p,
    ProjectGroup g,
    List<Task> tasks,
  ) {
    final byId = {for (final t in tasks) t.id: t};
    var total = 0;
    var completed = 0;
    for (final id in g.taskIds) {
      final t = byId[id];
      if (t == null) continue;
      total++;
      if (t.isCompleted) completed++;
    }
    return ProjectProgress(
      name: g.name,
      bonusExp: g.bonusExp,
      totalTasks: total,
      completedTasks: completed,
    );
  }

  /// 未割り当てクエスト一覧（taskProjects に登録が無いタスク）。
  static List<Task> unassignedTasks(Player p, List<Task> tasks) {
    return tasks.where((t) => !p.taskProjects.containsKey(t.id)).toList(growable: false);
  }

  /// 未完了が先（ratio 降順）→ 完了は後ろ。同一は名前昇順。非破壊。
  static List<ProjectProgress> sortByProgress(List<ProjectProgress> items) {
    final sorted = List.of(items);
    sorted.sort((a, b) {
      if (a.isComplete != b.isComplete) return a.isComplete ? 1 : -1;
      final byRatio = b.ratio.compareTo(a.ratio);
      if (byRatio != 0) return byRatio;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  /// 計画の陣（プロジェクト機能）の使用可否。Mystic 現職＋Lv10 達成。
  static bool canUseProjectSkill(Player p) =>
      p.canUseSkill(Job.mystic) &&
      (p.jobLevels[Job.mystic] ?? 1) >= JobSkill.mysticProject.requiredLevel;

  /// 現在職業のスキル一覧。isUnlocked は職業の使用可否＋必要レベル到達。
  static List<JobSkillInfo> skillsFor(Player p) {
    final job = p.currentJob;
    final jobLevel = p.jobLevels[job] ?? 1;
    return JobSkill.values
        .where((s) => s.job == job)
        .map((s) => JobSkillInfo(
              skill: s,
              requiredLevel: s.requiredLevel,
              isUnlocked: p.canUseSkill(s.job) && jobLevel >= s.requiredLevel,
            ))
        .toList(growable: false);
  }
}