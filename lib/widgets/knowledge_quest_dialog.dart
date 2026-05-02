import 'package:flutter/material.dart';
import '../data/quiz_data.dart';
import '../core/accessibility/semantic_helper.dart';
import '../core/testing/widget_keys.dart';

/// 知識クエスト（クイズ）ダイアログ
///
/// タスク完了後に 30% の確率で表示される。
/// 正解時は [onCorrect] が呼ばれ、呼び出し元が awardKnowledgeBonus() を実行する。
/// スキップ・不正解時はボーナスなし。
class KnowledgeQuestDialog extends StatefulWidget {
  final QuizQuestion quest;
  final VoidCallback onCorrect;
  final VoidCallback onSkip;

  const KnowledgeQuestDialog({
    super.key,
    required this.quest,
    required this.onCorrect,
    required this.onSkip,
  });

  /// showDialog を呼ぶ静的ヘルパー
  static Future<void> show(
    BuildContext context, {
    required QuizQuestion quest,
    required VoidCallback onCorrect,
    required VoidCallback onSkip,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => KnowledgeQuestDialog(
        quest: quest,
        onCorrect: onCorrect,
        onSkip: onSkip,
      ),
    );
  }

  @override
  State<KnowledgeQuestDialog> createState() => _KnowledgeQuestDialogState();
}

class _KnowledgeQuestDialogState extends State<KnowledgeQuestDialog> {
  int? _selectedIndex;
  bool _answered = false;

  void _onChoiceTap(int index) {
    if (_answered) return;
    setState(() {
      _selectedIndex = index;
      _answered = true;
    });

    if (index == widget.quest.correctIndex) {
      widget.onCorrect();
      // 正解の場合は少し間を置いて自動クローズ
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
    // 不正解は手動クローズ（正解を確認してから閉じてもらう）
  }

  Color _choiceColor(int index) {
    if (!_answered) return Colors.white10;
    if (index == widget.quest.correctIndex) return Colors.green.withValues(alpha: 0.6);
    if (index == _selectedIndex) return Colors.red.withValues(alpha: 0.5);
    return Colors.white10;
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final isCorrect = _answered && _selectedIndex == quest.correctIndex;

    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_knowledge_quest',
      child: Dialog(
        key: AppKeys.confirmDialog,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.purpleAccent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー
              Row(
                children: [
                  const Text('📚', style: TextStyle(fontSize: 28)),
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
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '正解で EXP +${quest.expBonusPercent}% ボーナス！',
                          style: const TextStyle(color: Colors.amber, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 問題文
              Text(
                quest.question,
                style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 選択肢
              ...List.generate(quest.choices.length, (i) {
                final label = String.fromCharCode('A'.codeUnitAt(0) + i);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SemanticHelper.interactive(
                    testId: '${SemanticTypes.button}_quiz_choice_$i',
                    child: InkWell(
                      key: Key('quiz_choice_$i'),
                      onTap: () => _onChoiceTap(i),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _choiceColor(i),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _answered && i == quest.correctIndex
                                ? Colors.green
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text('$label. ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            Expanded(
                              child: Text(
                                quest.choices[i],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                            if (_answered && i == quest.correctIndex)
                              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                            if (_answered && i == _selectedIndex && i != quest.correctIndex)
                              const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // 結果フィードバック
              if (_answered) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
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
                            ? '✅ 正解！ +${quest.expBonusPercent}% EXP ボーナス！'
                            : '❌ 残念… 正解は「${quest.choices[quest.correctIndex]}」',
                        style: TextStyle(
                          color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (quest.explanation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '💡 ${quest.explanation}',
                          style: const TextStyle(color: Colors.amber, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // アクションボタン
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_answered)
                    SemanticHelper.interactive(
                      testId: '${SemanticTypes.button}_skip_quiz',
                      label: 'スキップ',
                      child: TextButton(
                        key: AppKeys.tutorialSkip,
                        onPressed: () {
                          widget.onSkip();
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'スキップ（ボーナスなし）',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ),
                    ),
                  if (_answered && !isCorrect)
                    SemanticHelper.interactive(
                      testId: '${SemanticTypes.button}_close_quiz',
                      label: '閉じる',
                      child: ElevatedButton(
                        key: AppKeys.closeButton,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('閉じる'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
