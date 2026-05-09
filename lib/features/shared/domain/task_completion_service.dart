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

  const TaskCompletionResult({
    required this.leveledUp,
    required this.coinsGained,
    required this.expGain,
    required this.bonusMessages,
    required this.showFatiguePopup,
    required this.shouldResetFatiguePopup,
    this.quizQuestion,
  });
}

/// タスク完了のロジック（GameViewModelから分離）
class TaskCompletionService {
  final Random _rng;

  TaskCompletionService({Random? rng}) : _rng = rng ?? Random();

  /// タスクを完了し、結果を返す。PlayerとTaskは呼び出し元で更新する。
  /// 戻り値がnullの場合は完了不可（サブタスク未完了など）。
  TaskCompletionResult? complete({
    required Task task,
    required Player player,
    required bool hasShownFatiguePopupToday,
    required bool knowledgeQuestEnabled,
  }) {
    // Wizard: サブタスク完了チェック
    if (player.canUseSkill(Job.wizard) && task.subTasks.isNotEmpty) {
      if (task.subTasks.any((s) => !s.isCompleted)) {
        return null;
      }
    }

    // Cleric: 繰り返しタスクは isCompleted にしない
    if (player.canUseSkill(Job.cleric) &&
        task.repeatInterval != RepeatInterval.none) {
      task.lastCompletedAt = DateTime.now();
    } else {
      task.isCompleted = true;
      task.status = TaskStatus.inGuild;
    }

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

    if (isOverdue) {
      // 期限切れペナルティ: 強制クイズ + EXP減少
      quizQuestion = QuizService.drawHardQuizQuestion();
      bonusMessages.add("⏰ 期限切れ！クイズに答えてペナルティを軽減せよ！");

      // EXPペナルティ: 期限超過時間に応じて減少（最低50%まで）
      final overdueHours = DateTime.now().difference(task.deadline!).inHours;
      final penaltyRate = (1.0 - (overdueHours * 0.01)).clamp(0.5, 1.0);
      expGain = (expGain * penaltyRate).round();
    } else if (knowledgeQuestEnabled) {
      quizQuestion = QuizService.drawQuizQuestion();
    }

    return TaskCompletionResult(
      leveledUp: leveledUp,
      coinsGained: coinsGained,
      expGain: expGain,
      bonusMessages: bonusMessages,
      showFatiguePopup: showFatiguePopup,
      shouldResetFatiguePopup: shouldResetFatiguePopup,
      quizQuestion: quizQuestion,
    );
  }
}
