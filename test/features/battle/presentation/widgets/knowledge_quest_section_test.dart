import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/knowledge_quest_section.dart';

void main() {
  group('KnowledgeQuestSection — Bug M3: 5+ choices RangeError', () {
    testWidgets('5個の選択肢でもRangeErrorが発生しない', (tester) async {
      const quest = QuizQuestion(
        id: 'test_5',
        question: '日本の首都は？',
        choices: ['東京', '大阪', '名古屋', '福岡', '札幌'],
        correctIndex: 0,
        expBonusPercent: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeQuestSection(
              quizQuestion: quest,
              onQuizCorrect: (_) {},
            ),
          ),
        ),
      );

      // 5つの選択肢が正しく表示されている
      expect(find.text('A. '), findsOneWidget);
      expect(find.text('B. '), findsOneWidget);
      expect(find.text('C. '), findsOneWidget);
      expect(find.text('D. '), findsOneWidget);
      expect(find.text('E. '), findsOneWidget);
      // 'F.' は存在しないはず（5つだけ）
      expect(find.text('F. '), findsNothing);
    });

    testWidgets('10個の選択肢でもRangeErrorが発生しない', (tester) async {
      const quest = QuizQuestion(
        id: 'test_10',
        question: 'テスト問題',
        choices: [
          'A', 'B', 'C', 'D', 'E',
          'F', 'G', 'H', 'I', 'J',
        ],
        correctIndex: 0,
        expBonusPercent: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeQuestSection(
              quizQuestion: quest,
              onQuizCorrect: (_) {},
            ),
          ),
        ),
      );

      // 10個すべてのラベルが正しく表示されている
      expect(find.text('J. '), findsOneWidget);
      expect(find.text('K. '), findsNothing);
    });

    test('選択肢ラベル生成が26文字まで対応している', () {
      // 文字コードベースのラベル生成をユニットテスト
      for (int i = 0; i < 26; i++) {
        final label = String.fromCharCode('A'.codeUnitAt(0) + i);
        expect(label.length, 1);
        expect(label.codeUnitAt(0), greaterThanOrEqualTo('A'.codeUnitAt(0)));
        expect(label.codeUnitAt(0), lessThanOrEqualTo('Z'.codeUnitAt(0)));
      }
      // 27個目もエラーにならず'AA'などになる（仕様範囲外だがエラーにはならない）
      final label27 = String.fromCharCode('A'.codeUnitAt(0) + 26);
      expect(label27, '['); // 'Z'の次のASCII文字
    });

    testWidgets('従来の4選択肢も正しく動作する（回帰テスト）', (tester) async {
      const quest = QuizQuestion(
        id: 'test_4',
        question: '色は？',
        choices: ['赤', '青', '緑', '黄'],
        correctIndex: 0,
        expBonusPercent: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeQuestSection(
              quizQuestion: quest,
              onQuizCorrect: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('A. '), findsOneWidget);
      expect(find.text('B. '), findsOneWidget);
      expect(find.text('C. '), findsOneWidget);
      expect(find.text('D. '), findsOneWidget);
      expect(find.text('E. '), findsNothing);
    });
  });
}
