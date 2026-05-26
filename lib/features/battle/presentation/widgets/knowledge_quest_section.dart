import 'package:flutter/material.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// 戦果報告書内にインライン表示される知識クエストセクション
class KnowledgeQuestSection extends StatefulWidget {
  final QuizQuestion quizQuestion;
  final void Function(QuizQuestion)? onQuizCorrect;
  final VoidCallback? onQuizWrong;
  final bool isOverdueBoss;

  const KnowledgeQuestSection({
    super.key,
    required this.quizQuestion,
    this.onQuizCorrect,
    this.onQuizWrong,
    this.isOverdueBoss = false,
  });

  @override
  State<KnowledgeQuestSection> createState() => _KnowledgeQuestSectionState();
}

class _KnowledgeQuestSectionState extends State<KnowledgeQuestSection> {
  int? _selectedIndex;
  bool _quizAnswered = false;

  void _onChoiceTap(int index) {
    if (_quizAnswered) return;
    setState(() {
      _selectedIndex = index;
      _quizAnswered = true;
    });
    if (index == widget.quizQuestion.correctIndex) {
      widget.onQuizCorrect?.call(widget.quizQuestion);
    } else if (widget.isOverdueBoss) {
      // 刻の番人クイズ誤答 → 追加ペナルティ
      widget.onQuizWrong?.call();
    }
  }

  Color _choiceColor(int index) {
    if (!_quizAnswered) return Colors.white10;
    if (index == widget.quizQuestion.correctIndex) {
      return Colors.green.withValues(alpha: 0.6);
    }
    if (index == _selectedIndex) return Colors.red.withValues(alpha: 0.5);
    return Colors.white10;
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quizQuestion;
    final isCorrect = _quizAnswered && _selectedIndex == quest.correctIndex;
    final isBoss = widget.isOverdueBoss;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isBoss
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBoss
              ? Colors.redAccent.withValues(alpha: 0.6)
              : Colors.purpleAccent.withValues(alpha: 0.4),
          width: isBoss ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isBoss ? '⏰' : '📚', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBoss ? '⚔️ 刻の番人との戦い！' : '知識クエスト！',
                      style: TextStyle(
                        color: isBoss ? Colors.redAccent : Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (isBoss)
                      const Text(
                        '誤答すると追加ペナルティ！正解で討伐！',
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 10),
                      )
                    else
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
          Text(
            quest.question,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(quest.choices.length, (i) {
            final label = String.fromCharCode('A'.codeUnitAt(0) + i);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'quiz_choice_$i'),
                label: '選択肢 ${String.fromCharCode('A'.codeUnitAt(0) + i)}',
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
                      color: _quizAnswered && i == quest.correctIndex
                          ? Colors.green
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text('$label. ',
                          style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      Expanded(
                        child: Text(quest.choices[i],
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      if (_quizAnswered && i == quest.correctIndex)
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                      if (_quizAnswered && i == _selectedIndex && i != quest.correctIndex)
                        const Icon(Icons.cancel, color: Colors.redAccent, size: 16),
                    ],
                  ),
              ),
            ),
              ),
            );
          }),
          if (_quizAnswered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCorrect
                        ? (isBoss
                            ? '⚔️ 刻の番人を討伐！ +${quest.expBonusPercent}% EXP ボーナス！'
                            : '✅ 正解！ +${quest.expBonusPercent}% EXP ボーナス！')
                        : (isBoss
                            ? '💀 刻の番人の呪い！追加ペナルティ！正解は「${quest.choices[quest.correctIndex]}」'
                            : '❌ 残念… 正解は「${quest.choices[quest.correctIndex]}」'),
                    style: TextStyle(
                      color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (quest.explanation != null) ...[
                    const SizedBox(height: 4),
                    Text('💡 ${quest.explanation}',
                        style: const TextStyle(color: Colors.amber, fontSize: 10)),
                  ],
                ],
              ),
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'next_quiz'),
                  label: '次の問題へ',
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('次へ',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
