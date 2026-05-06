import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// 戦果報告書 — 討伐後の統合ダイアログ
///
/// 従来は討伐完了→レベルアップ→知識クエスト→疲労の4連ダイアログだったものを
/// 1枚の報告書に統合する。
///
/// 表示項目（条件付き）:
///   - 獲得金貨 + ボーナスメッセージ
///   - レベルアップ（Lv.X → Lv.Y）
///   - 知識クエスト（インライン出題）
///   - 疲労警告
class BattleReportDialog extends StatefulWidget {
  final int coinsGained;
  final List<String> bonusMessages;
  final bool leveledUp;
  final int previousLevel;
  final int newLevel;
  final int currentExp;
  final int expToNextLevel;
  final QuizQuestion? quizQuestion;
  final void Function(QuizQuestion)? onQuizCorrect;
  final int? baseExp;
  final String? fatigueWarning;
  final int? fatigueWarnThreshold;
  final int? dailyTasksCompleted;

  const BattleReportDialog({
    super.key,
    required this.coinsGained,
    this.bonusMessages = const [],
    this.leveledUp = false,
    this.previousLevel = 1,
    this.newLevel = 1,
    this.currentExp = 0,
    this.expToNextLevel = 50,
    this.quizQuestion,
    this.onQuizCorrect,
    this.baseExp,
    this.fatigueWarning,
    this.fatigueWarnThreshold,
    this.dailyTasksCompleted,
  });

  /// showDialog を呼ぶ静的ヘルパー
  static Future<void> show(
    BuildContext context, {
    required int coinsGained,
    List<String> bonusMessages = const [],
    bool leveledUp = false,
    int previousLevel = 1,
    int newLevel = 1,
    int currentExp = 0,
    int expToNextLevel = 50,
    QuizQuestion? quizQuestion,
    void Function(QuizQuestion)? onQuizCorrect,
    int? baseExp,
    String? fatigueWarning,
    int? fatigueWarnThreshold,
    int? dailyTasksCompleted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BattleReportDialog(
        coinsGained: coinsGained,
        bonusMessages: bonusMessages,
        leveledUp: leveledUp,
        previousLevel: previousLevel,
        newLevel: newLevel,
        currentExp: currentExp,
        expToNextLevel: expToNextLevel,
        quizQuestion: quizQuestion,
        onQuizCorrect: onQuizCorrect,
        baseExp: baseExp,
        fatigueWarning: fatigueWarning,
        fatigueWarnThreshold: fatigueWarnThreshold,
        dailyTasksCompleted: dailyTasksCompleted,
      ),
    );
  }

  @override
  State<BattleReportDialog> createState() => _BattleReportDialogState();
}

class _BattleReportDialogState extends State<BattleReportDialog> {
  // 知識クエスト解答状態
  int? _selectedIndex;
  bool _quizAnswered = false;

  void _onChoiceTap(int index) {
    if (_quizAnswered || widget.quizQuestion == null) return;
    setState(() {
      _selectedIndex = index;
      _quizAnswered = true;
    });

    if (index == widget.quizQuestion!.correctIndex) {
      widget.onQuizCorrect?.call(widget.quizQuestion!);
    }
  }

  Color _choiceColor(int index) {
    if (!_quizAnswered || widget.quizQuestion == null) return Colors.white10;
    if (index == widget.quizQuestion!.correctIndex) {
      return Colors.green.withValues(alpha: 0.6);
    }
    if (index == _selectedIndex) return Colors.red.withValues(alpha: 0.5);
    return Colors.white10;
  }

  @override
  Widget build(BuildContext context) {
    final isQuizCorrect =
        _quizAnswered &&
        widget.quizQuestion != null &&
        _selectedIndex == widget.quizQuestion!.correctIndex;

    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_battle_report',
      child: Dialog(
        key: AppKeys.battleReportDialog,
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
                // ━━━ ヘッダー ━━━
                const Text(
                  '⚔️ 戦果報告書',
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFF4A90D9),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 2,
                  width: 120,
                  color: const Color(0xFF4A90D9).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),

                // ━━━ 獲得金貨 ━━━
                _buildCoinsSection(),
                const SizedBox(height: 16),

                // ━━━ ボーナスメッセージ ━━━
                if (widget.bonusMessages.isNotEmpty) ...[
                  _buildBonusSection(),
                  const SizedBox(height: 16),
                ],

                // ━━━ レベルアップ ━━━
                if (widget.leveledUp) ...[
                  _buildLevelUpSection(),
                  const SizedBox(height: 16),
                ],

                // ━━━ 知識クエスト ━━━
                if (widget.quizQuestion != null) ...[
                  _buildKnowledgeQuestSection(isQuizCorrect),
                  const SizedBox(height: 16),
                ],

                // ━━━ 疲労警告 ━━━
                if (widget.fatigueWarning != null ||
                    (widget.fatigueWarnThreshold != null &&
                        widget.dailyTasksCompleted != null &&
                        widget.dailyTasksCompleted! >=
                            widget.fatigueWarnThreshold!)) ...[
                  _buildFatigueSection(),
                  const SizedBox(height: 20),
                ],

                // ━━━ 閉じるボタン ━━━
                SemanticHelper.interactive(
                  testId: '${SemanticTypes.button}_battle_report_close',
                  label: '冒険を続ける',
                  child: ElevatedButton(
                    key: AppKeys.battleReportClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '冒険を続ける',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoinsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🪙', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Text(
          '${widget.coinsGained} 金貨 を獲得！',
          style: const TextStyle(
            fontSize: 20,
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBonusSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎉 ボーナス',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          ...widget.bonusMessages.map(
            (msg) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B5C00), Color(0xFFFFD700), Color(0xFF7B5C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.amber, blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const Text('⬆', style: TextStyle(fontSize: 36)),
          Text(
            'LEVEL UP!',
            style: GoogleFonts.pressStart2p(
              fontSize: 20,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lv.${widget.previousLevel} → Lv.${widget.newLevel}',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '次のレベルまで ${widget.expToNextLevel} EXP',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeQuestSection(bool isCorrect) {
    final quest = widget.quizQuestion!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '知識クエスト！',
                      style: TextStyle(
                        color: Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '正解で EXP +${quest.expBonusPercent}% ボーナス！',
                      style: const TextStyle(color: Colors.amber, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 問題文
          Text(
            quest.question,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          // 選択肢
          ...List.generate(quest.choices.length, (i) {
            final label = String.fromCharCode('A'.codeUnitAt(0) + i);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                key: Key('quiz_choice_$i'),
                onTap: () => _onChoiceTap(i),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _choiceColor(i),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          _quizAnswered && i == quest.correctIndex
                              ? Colors.green
                              : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$label. ',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      Expanded(
                        child: Text(
                          quest.choices[i],
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      if (_quizAnswered && i == quest.correctIndex)
                        const Icon(Icons.check_circle,
                            color: Colors.greenAccent, size: 16),
                      if (_quizAnswered &&
                          i == _selectedIndex &&
                          i != quest.correctIndex)
                        const Icon(Icons.cancel,
                            color: Colors.redAccent, size: 16),
                    ],
                  ),
                ),
              ),
            );
          }),

          // 結果フィードバック
          if (_quizAnswered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isCorrect
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect
                        ? '✅ 正解！ +${quest.expBonusPercent}% EXP ボーナス！'
                        : '❌ 残念… 正解は「${quest.choices[quest.correctIndex]}」',
                    style: TextStyle(
                      color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (quest.explanation != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '💡 ${quest.explanation}',
                      style: const TextStyle(color: Colors.amber, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            // 不正解時のスキップボタン（正解時は自動で閉じてOK）
            if (!isCorrect) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  // 何もしない（ユーザーは「冒険を続ける」で閉じる）
                  child: const Text(
                    '次へ',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFatigueSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.fatigueWarning ??
                  '疲労が蓄積しています。宿屋で休むことをお勧めします。',
              style: const TextStyle(
                color: Colors.orangeAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),  // close Text
          ),  // close Expanded
        ],
      ),
    );
  }
}
