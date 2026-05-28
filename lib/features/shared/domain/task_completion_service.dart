import 'dart:math';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/services/fatigue_service.dart';
import 'package:rpg_todo/domain/services/title_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';

/// タスク完了時の計算結果
class TaskCompletionResult {
  final bool leveledUp;
  final int coinsGained;
  final int expGain;
  final List<String> bonusMessages;
  final bool showFatiguePopup;
  final bool shouldResetFatiguePopup;
  final QuizQuestion? quizQuestion;
  final bool isOverdueBoss;
  /// 刻の番人クイズに誤答した場合の追加ペナルティEXP（0ならペナルティなし）
  final int wrongAnswerPenaltyExp;
  /// 刻の番人クイズに誤答した場合の追加ペナルティ文（0ならペナルティなし）
  final int wrongAnswerPenaltyCoins;

  const TaskCompletionResult({
    required this.leveledUp,
    required this.coinsGained,
    required this.expGain,
    required this.bonusMessages,
    required this.showFatiguePopup,
    required this.shouldResetFatiguePopup,
    this.quizQuestion,
    this.isOverdueBoss = false,
    this.wrongAnswerPenaltyExp = 0,
    this.wrongAnswerPenaltyCoins = 0,
  });
}

/// タスク完了のロジック（GameViewModelから分離）
class TaskCompletionService {
  final Random _rng;

  TaskCompletionService({Random? rng}) : _rng = rng ?? Random();

  /// タスクを完了し、結果を返す。PlayerとTaskは呼び出し元で更新する。
  /// 戻り値がnullの場合は完了不可（サブタスク未完了など）。
  /// [allTasks] は wizardProject ボーナス判定用の全タスクリスト（任意）。
  TaskCompletionResult? complete({
    required Task task,
    required Player player,
    required bool hasShownFatiguePopupToday,
    required bool knowledgeQuestEnabled,
    List<Task>? allTasks,
  }) {
    // Wizard Lv1: 分割の理 — サブタスク完了チェック
    if (player.isSkillEquipped(JobSkill.wizardSubtask) && task.subTasks.isNotEmpty) {
      if (task.subTasks.any((s) => !s.isCompleted)) {
        return null;
      }
    }

    // Cleric: repeatAfterDays の処理
    if (player.canUseSkill(Job.cleric) && task.repeatAfterDays != null) {
      task.lastCompletedAt = DateTime.now();
    } else if (
        // Ronin (冒険者): 繰り返しタスクは isCompleted にせず lastCompletedAt を更新
        // 後方互換: Cleric mastery でも動作
        task.repeatInterval != RepeatInterval.none &&
        (player.hasSkill(JobSkill.roninRepeatTask) ||
         player.canUseSkill(Job.cleric))) {
      task.lastCompletedAt = DateTime.now();
    } else {
      task.isCompleted = true;
      task.status = TaskStatus.inGuild;
    }

    // Cleric Lv10: 連続の誓い — タスク完了をstreakに記録
    player.recordTaskCompletion(task.id, DateTime.now());

    final bonusMessages = <String>[];
    final fatigueMultiplier = FatigueService.fatigueMultiplier(player);

    // 疲労メッセージ
    if (player.dailyTasksCompleted >= FatigueService.severeThreshold(player)) {
      bonusMessages.add("🌙 今日の英雄は十分戦った。宿屋で休んで明日に備えよ！");
    } else if (player.dailyTasksCompleted >= FatigueService.warnThreshold(player)) {
      bonusMessages.add("🍺 疲れが溜まってきたぞ。宿屋で一息つくか？");
    }

    // XP計算
    int expGain = switch (task.rank) {
      QuestRank.S => 1000,
      QuestRank.A => 300,
      QuestRank.B => 100,
    };

    // Warrior: コンボボーナス
    if (player.canUseSkill(Job.warrior)) {
      player.comboCount++;
      final comboBonus = player.comboCount * 10;
      expGain += comboBonus;
      if (player.comboCount > 1) {
        bonusMessages.add("⚔️ ${player.comboCount}コンボ！ +$comboBonus EXP");
      }
    } else {
      player.comboCount = 0;
    }

    expGain = (expGain * fatigueMultiplier).round();

    // 称号ボーナス
    if (player.equippedTitle != null) {
      expGain = (expGain * 1.05).round();
    }

    // Cleric Lv10: 連続の誓い — 7日間streakで+20% EXP
    if (player.getTaskStreakBonus(task.id) > 1.0) {
      expGain = (expGain * player.getTaskStreakBonus(task.id)).round();
      bonusMessages.add("📿 連続の誓いボーナス！ +20% EXP");
    }

    // コイン計算
    int coinsGained = task.rank == QuestRank.S
        ? 100
        : task.rank == QuestRank.A
            ? 30
            : 10;
    coinsGained = (coinsGained * fatigueMultiplier).round();

    // レアドロップ
    final dropChance = (player.level * 0.02).clamp(0.01, 0.5);
    if (_rng.nextDouble() < dropChance) {
      final rareBonus = (coinsGained * 5 * fatigueMultiplier).round();
      if (rareBonus > 0) {
        coinsGained += rareBonus;
        bonusMessages.add("✨ レアドロップ発見！！ +$rareBonus文");
      }
    }

    // カウント更新
    player.dailyTasksCompleted++;
    if (task.rank == QuestRank.S) player.weeklySRankCompleted++;
    player.totalTasksCompleted++;
    if (task.rank == QuestRank.S) player.totalSRankCompleted++;
    if (task.rank == QuestRank.A) player.totalARankCompleted++;
    if (task.rank == QuestRank.B) player.totalBRankCompleted++;

    TitleService.checkTitles(player, bonusMessages);

    // デイリーミッション
    if (player.dailyTasksCompleted == 3) {
      coinsGained += 200;
      bonusMessages.add("📅 デイリーミッション達成！ +200文");
    }
    // ウィークリーミッション
    if (task.rank == QuestRank.S && player.weeklySRankCompleted == 1) {
      coinsGained += 500;
      bonusMessages.add("🏆 ウィークリーSランク達成！ +500文");
    }

    player.coins += coinsGained;
    final leveledUp = player.addExp(expGain);

    // 疲労MAXポップアップ
    bool showFatiguePopup = false;
    bool shouldResetFatiguePopup = false;
    if (player.dailyTasksCompleted >= FatigueService.severeThreshold(player) &&
        !hasShownFatiguePopupToday) {
      showFatiguePopup = true;
      shouldResetFatiguePopup = true;
    }

    // 知識クエスト抽選
    QuizQuestion? quizQuestion;
    final isOverdue = task.deadline != null && task.deadline!.isBefore(DateTime.now());
    bool isOverdueBoss = false;
    int wrongAnswerPenaltyExp = 0;
    int wrongAnswerPenaltyCoins = 0;

    if (isOverdue) {
      // 刻の番人（TimeWarden）ボス戦: 期限切れ専用クイズを強制出題
      quizQuestion = QuizService.drawHardQuizQuestion();
      bonusMessages.add("⏰ 刻の番人が現れた！「汝、時を無駄にせし者よ…」");
      bonusMessages.add("💀 知識の刃で刻の番人を打ち破れ！");
      isOverdueBoss = true;

      // 倍ペナルティ: 報酬一律半減
      expGain = (expGain * 0.5).round();
      coinsGained = (coinsGained * 0.5).round();

      // 誤答時の追加ペナルティ（半減後報酬のさらに50%を没収）
      // 正解すればペナルティを回避できる
      wrongAnswerPenaltyExp = (expGain * 0.5).round();
      wrongAnswerPenaltyCoins = (coinsGained * 0.5).round();
    } else if (knowledgeQuestEnabled) {
      quizQuestion = QuizService.drawQuizQuestion();
    }

    // ReverseBonus: 期限内・残り1時間以内でXP 1.5倍
    if (!isOverdue && task.deadline != null) {
      final remaining = task.deadline!.difference(DateTime.now());
      if (remaining.inMinutes <= 60 && remaining.inMinutes > 0) {
        expGain = (expGain * 1.5).round();
        bonusMessages.add("🔥 ギリギリ討伐ボーナス！報酬1.5倍！");
      }
    }

    // Wizard Lv10: 計画の陣 — プロジェクト全完了ボーナス
    int projectBonusExp = 0;
    if (player.isSkillEquipped(JobSkill.wizardProject) &&
        allTasks != null &&
        allTasks.isNotEmpty) {
      final projectName = player.taskProjects[task.id];
      if (projectName != null) {
        final project = player.projects
            .where((p) => p.name == projectName)
            .firstOrNull;
        if (project != null && project.bonusExp > 0) {
          // プロジェクトに属する全タスクが完了しているか
          final allProjectTaskIds = project.taskIds.toSet();
          // 現在完了したタスク + 他の全タスクの完了状態を確認
          final allProjectTasks = allTasks
              .where((t) => allProjectTaskIds.contains(t.id));
          final allDone = allProjectTasks.every((t) =>
              t.isCompleted || t.id == task.id);
          if (allDone) {
            projectBonusExp = project.bonusExp;
            expGain += projectBonusExp;
            bonusMessages.add("🗺️ 計画の陣：${projectName} 全踏破！ +$projectBonusExp EXP");
          }
        }
      }
    }

    return TaskCompletionResult(
      leveledUp: leveledUp,
      coinsGained: coinsGained,
      expGain: expGain,
      bonusMessages: bonusMessages,
      showFatiguePopup: showFatiguePopup,
      shouldResetFatiguePopup: shouldResetFatiguePopup,
      quizQuestion: quizQuestion,
      isOverdueBoss: isOverdueBoss,
      wrongAnswerPenaltyExp: wrongAnswerPenaltyExp,
      wrongAnswerPenaltyCoins: wrongAnswerPenaltyCoins,
    );
  }
}
