import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'battle_result_header.dart';
import 'bonus_message_list.dart';
import 'level_up_section.dart';
import 'knowledge_quest_section.dart';
import 'fatigue_warning_section.dart';
import 'reflection_input_dialog.dart';
import 'zanshin_dialog.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

class BattleReportDialog extends StatefulWidget {
  final int coinsGained;
  final List<String> bonusMessages;
  final bool leveledUp;
  final int previousLevel, newLevel, currentExp, expToNextLevel;
  final QuizQuestion? quizQuestion;
  final void Function(QuizQuestion)? onQuizCorrect;
  final VoidCallback? onQuizWrong;
  final bool isOverdueBoss;
  final String? fatigueWarning;

  // v2.1: 振り返り入力連携
  final String? taskId;
  final String? taskTitle;
  final QuestRank? aiDifficulty;
  final int inputBonusExp;
  final VoidCallback? onReflectionSubmit;
  final Player? player;

  const BattleReportDialog({
    super.key,
    required this.coinsGained,
    this.bonusMessages = const [],
    this.leveledUp = false,
    this.previousLevel = 1, this.newLevel = 1,
    this.currentExp = 0, this.expToNextLevel = 50,
    this.quizQuestion, this.onQuizCorrect,
    this.onQuizWrong,
    this.isOverdueBoss = false,
    this.fatigueWarning,
    this.taskId,
    this.taskTitle,
    this.aiDifficulty,
    this.inputBonusExp = 50,
    this.onReflectionSubmit,
    this.player,
  });

  static Future<void> show(BuildContext context, {
    required int coinsGained, List<String> bonusMessages = const [],
    bool leveledUp = false, int previousLevel = 1, int newLevel = 1,
    int currentExp = 0, int expToNextLevel = 50,
    QuizQuestion? quizQuestion, void Function(QuizQuestion)? onQuizCorrect,
    VoidCallback? onQuizWrong, bool isOverdueBoss = false,
    int? baseExp, String? fatigueWarning,
    int? fatigueWarnThreshold, int? dailyTasksCompleted,
    String? taskId, String? taskTitle, QuestRank? aiDifficulty,
    int inputBonusExp = 50, VoidCallback? onReflectionSubmit,
    Player? player,
  }) => showDialog<void>(
    context: context, barrierDismissible: false,
    builder: (_) => BattleReportDialog(
      coinsGained: coinsGained, bonusMessages: bonusMessages,
      leveledUp: leveledUp, previousLevel: previousLevel, newLevel: newLevel,
      currentExp: currentExp, expToNextLevel: expToNextLevel,
      quizQuestion: quizQuestion, onQuizCorrect: onQuizCorrect,
      onQuizWrong: onQuizWrong, isOverdueBoss: isOverdueBoss,
      fatigueWarning: fatigueWarning,
      taskId: taskId, taskTitle: taskTitle, aiDifficulty: aiDifficulty,
      inputBonusExp: inputBonusExp, onReflectionSubmit: onReflectionSubmit,
      player: player,
    ),
  );

  @override
  State<BattleReportDialog> createState() => _BattleReportDialogState();
}

class _BattleReportDialogState extends State<BattleReportDialog> {
  bool _reflectionShown = false;

  void _openReflection() {
    if (_reflectionShown || widget.taskId == null) return;
    _reflectionShown = true;

    final isSamurai = widget.player?.isSamuraiLine ?? false;

    if (isSamurai && widget.player?.unlockedSkillIds.contains('war_zanshin') == true) {
      // 侍系 + 残心解放済 → 残心【初段】ダイアログ
      ZanshinDialog.show(
        context,
        taskId: widget.taskId!,
        taskTitle: widget.taskTitle ?? '不明なクエスト',
        aiDifficulty: widget.aiDifficulty ?? QuestRank.B,
        inputBonusExp: widget.inputBonusExp,
        onKaishin: () {
          widget.onReflectionSubmit?.call();
        },
        onImashime: () {
          widget.onReflectionSubmit?.call();
        },
        player: widget.player,
      );
    } else if (isSamurai) {
      // 侍系だが残心未解放（浪人フロー）→ 即完了
      widget.onReflectionSubmit?.call();
    } else {
      // 非侍系 → 既存の振り返りダイアログ
      ReflectionInputDialog.show(
        context,
        taskId: widget.taskId!,
        taskTitle: widget.taskTitle ?? '不明なクエスト',
        aiDifficulty: widget.aiDifficulty ?? QuestRank.B,
        inputBonusExp: widget.inputBonusExp,
        onSaved: () {
          widget.onReflectionSubmit?.call();
        },
        player: widget.player,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReflection = widget.taskId != null && (widget.player?.isSamuraiLine ?? true);

    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_battle_report',
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4A90D9), width: 1.5),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BattleResultHeader(coinsGained: widget.coinsGained),
                const SizedBox(height: 12),
                if (widget.bonusMessages.isNotEmpty)
                  BonusMessageList(messages: widget.bonusMessages),
                if (widget.leveledUp) ...[
                  const SizedBox(height: 16),
                  LevelUpSection(
                    previousLevel: widget.previousLevel,
                    newLevel: widget.newLevel,
                    expToNextLevel: widget.expToNextLevel,
                  ),
                ],
                if (widget.quizQuestion != null)
                  KnowledgeQuestSection(
                    quizQuestion: widget.quizQuestion!,
                    onQuizCorrect: widget.onQuizCorrect,
                    onQuizWrong: widget.onQuizWrong,
                    isOverdueBoss: widget.isOverdueBoss,
                  ),
                if (widget.fatigueWarning != null)
                  FatigueWarningSection(fatigueWarning: widget.fatigueWarning),
                const SizedBox(height: 24),

                // v2.1: 戦後の一息ボタン
                if (hasReflection && !_reflectionShown) ...[
                  SemanticHelper.interactive(
                    testId: SemanticHelper.createTestId(
                        SemanticTypes.button, 'open_reflection'),
                    label: '戦後の一息を記す',
                    child: ElevatedButton.icon(
                      onPressed: _openReflection,
                      icon: const Text('🌳', style: TextStyle(fontSize: 18)),
                      label: const Text('戦後の一息を記す'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'close_report'),
                  label: '戦果報告を閉じる',
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: const Text('閉じる', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
