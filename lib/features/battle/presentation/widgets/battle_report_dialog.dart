import 'package:flutter/material.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'battle_result_header.dart';
import 'bonus_message_list.dart';
import 'level_up_section.dart';
import 'knowledge_quest_section.dart';
import 'fatigue_warning_section.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

class BattleReportDialog extends StatefulWidget {
  final int coinsGained;
  final List<String> bonusMessages;
  final bool leveledUp;
  final int previousLevel, newLevel, currentExp, expToNextLevel;
  final QuizQuestion? quizQuestion;
  final void Function(QuizQuestion)? onQuizCorrect;
  final String? fatigueWarning;

  const BattleReportDialog({
    super.key,
    required this.coinsGained,
    this.bonusMessages = const [],
    this.leveledUp = false,
    this.previousLevel = 1, this.newLevel = 1,
    this.currentExp = 0, this.expToNextLevel = 50,
    this.quizQuestion, this.onQuizCorrect, this.fatigueWarning,
  });

  static Future<void> show(BuildContext context, {
    required int coinsGained, List<String> bonusMessages = const [],
    bool leveledUp = false, int previousLevel = 1, int newLevel = 1,
    int currentExp = 0, int expToNextLevel = 50,
    QuizQuestion? quizQuestion, void Function(QuizQuestion)? onQuizCorrect,
    int? baseExp, String? fatigueWarning,
    int? fatigueWarnThreshold, int? dailyTasksCompleted,
  }) => showDialog<void>(
    context: context, barrierDismissible: false,
    builder: (_) => BattleReportDialog(
      coinsGained: coinsGained, bonusMessages: bonusMessages,
      leveledUp: leveledUp, previousLevel: previousLevel, newLevel: newLevel,
      currentExp: currentExp, expToNextLevel: expToNextLevel,
      quizQuestion: quizQuestion, onQuizCorrect: onQuizCorrect,
      fatigueWarning: fatigueWarning,
    ),
  );

  @override
  State<BattleReportDialog> createState() => _BattleReportDialogState();
}

class _BattleReportDialogState extends State<BattleReportDialog> {
  @override
  Widget build(BuildContext context) {
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
                  ),
                if (widget.fatigueWarning != null)
                  FatigueWarningSection(fatigueWarning: widget.fatigueWarning),
                const SizedBox(height: 24),
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
