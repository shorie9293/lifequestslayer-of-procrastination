import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class KozuchiQuestCard extends StatelessWidget {
  final KozuchiQuest quest;

  const KozuchiQuestCard({
    super.key,
    required this.quest,
  });

  @override
  Widget build(BuildContext context) {
    return SemanticHelper.container(
      testId: SemanticHelper.createTestId(
        SemanticTypes.section,
        'kozuchi_quest',
      ),
      child: Card(
        key: AppKeys.kozuchiQuestCard,
        color: const Color(0xFF1A0A2E),
        elevation: 12,
        shadowColor: Colors.amber.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.amber.withValues(alpha: 0.6),
            width: 2.0,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2D0A4E),
                Color(0xFF1A0A2E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        '🧘 Kozuchi試練',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // ステータス
                    Container(
                      key: AppKeys.kozuchiStatus,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: quest.isCompleted
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        quest.isCompleted ? '✅ 達成済み' : '未達成',
                        style: TextStyle(
                          color: quest.isCompleted
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // アドバイザー情報
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          quest.advisorEmoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'アドバイザー',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          quest.advisorLabel,
                          key: AppKeys.kozuchiAdvisor,
                          style: GoogleFonts.vt323(
                            fontSize: 22,
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // タイトル
                Text(
                  quest.title,
                  key: AppKeys.kozuchiQuestTitle,
                  style: GoogleFonts.vt323(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // 説明
                Text(
                  quest.description,
                  key: AppKeys.kozuchiQuestDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                // 支出目安額
                Container(
                  key: AppKeys.kozuchiOffering,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '💰',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '支出目安: ${quest.suggestedOffering}コイン',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
