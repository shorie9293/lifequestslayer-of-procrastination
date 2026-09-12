import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_tree.dart';

/// 修行の道標 — スキルツリーとジョブ進化の進捗スナップショット（道標§五 #30）。
///
/// 純粋ロジック: [Player] の不変スナップショットから進捗を算出する。
/// Hive や Supabase には依存せず、widget からも注入なしで再利用できる。

/// 一つのスキルツリー（侍/法師/陰陽師）の進捗。
class SkillTreeProgress {
  /// このツリーの所属ジョブ。
  final Job tree;

  /// 解放済みノード数。
  final int unlockedCount;

  /// ツリーの全ノード数。
  final int totalCount;

  /// 次に解放できるノード（前提条件が満たされている最安ノード）。
  /// 全ノード解放済みなら null。
  final SkillNode? nextNode;

  /// [nextNode] を今すぐ解放できるか（ポイントが足りているか）。
  final bool nextNodeAffordable;

  /// [nextNode] 解放までに足りないスキルポイント（0 なら解放可能）。
  final int pointsShortfall;

  const SkillTreeProgress({
    required this.tree,
    required this.unlockedCount,
    required this.totalCount,
    required this.nextNode,
    required this.nextNodeAffordable,
    required this.pointsShortfall,
  });

  bool get isComplete => unlockedCount >= totalCount;

  bool get hasNextNode => nextNode != null;
}

/// 一つのジョブの習得進捗。
class JobProgress {
  final Job job;

  /// 現在のレベル。
  final int level;

  /// 習得（マスター）に必要なレベル。冒険者は 10、他職は 14。
  final int masterLevel;

  /// 習得までに必要な残りレベル数（習得済みなら 0）。
  final int levelsToMaster;

  const JobProgress({
    required this.job,
    required this.level,
    required this.masterLevel,
    required this.levelsToMaster,
  });

  bool get isMastered => levelsToMaster <= 0;

  double get progressRatio =>
      (level / masterLevel).clamp(0.0, 1.0).toDouble();
}

/// 修行の道標スナップショット。
class SkillProgressionReport {
  /// 現在使えるスキルポイント。
  final int skillPoints;

  /// 3ツリー（侍/法師/陰陽師）の進捗。
  final List<SkillTreeProgress> trees;

  /// 4ジョブ（浪人/侍/法師/陰陽師）の習得進捗。
  final List<JobProgress> jobs;

  const SkillProgressionReport({
    required this.skillPoints,
    required this.trees,
    required this.jobs,
  });

  int get totalUnlocked =>
      trees.fold(0, (sum, t) => sum + t.unlockedCount);

  int get totalNodes => trees.fold(0, (sum, t) => sum + t.totalCount);
}

/// 修行の道標を算出する純粋サービス。
class SkillProgressionService {
  const SkillProgressionService._();

  /// [player] のスナップショットから進捗レポートを構築する。
  static SkillProgressionReport compute(Player player) {
    final unlockedIds = player.unlockedSkillIds;

    final trees = <SkillTreeProgress>[];
    for (final job in [Job.samurai, Job.monk, Job.mystic]) {
      final nodes = skillTreeDefinition.values
          .where((n) => n.tree == job)
          .toList()
        ..sort((a, b) => a.pointCost.compareTo(b.pointCost));

      final unlockedCount =
          nodes.where((n) => unlockedIds.contains(n.id)).length;

      // 次に解放できるノード = 未解放 & 前提条件済み & 最安
      SkillNode? next;
      for (final node in nodes) {
        if (unlockedIds.contains(node.id)) continue;
        final prereqsMet =
            node.prerequisites.every(unlockedIds.contains);
        if (!prereqsMet) continue;
        next = node;
        break;
      }

      final raw =
          next == null ? 0 : next.pointCost - player.skillPoints;
      final shortfall = raw > 0 ? raw : 0;

      trees.add(SkillTreeProgress(
        tree: job,
        unlockedCount: unlockedCount,
        totalCount: nodes.length,
        nextNode: next,
        nextNodeAffordable: next != null && shortfall == 0,
        pointsShortfall: shortfall,
      ));
    }

    final jobs = [Job.adventurer, Job.samurai, Job.monk, Job.mystic]
        .map((job) {
      final level = player.jobLevels[job] ?? 1;
      final masterLevel = job == Job.adventurer ? 10 : 14;
      return JobProgress(
        job: job,
        level: level,
        masterLevel: masterLevel,
        levelsToMaster: (masterLevel - level).clamp(0, 1 << 31),
      );
    }).toList();

    return SkillProgressionReport(
      skillPoints: player.skillPoints,
      trees: trees,
      jobs: jobs,
    );
  }
}