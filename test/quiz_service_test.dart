import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/services/quiz_service.dart';
import 'package:rpg_todo/data/quiz_data.dart';

void main() {
  group('QuizService', () {
    setUp(() {
      // テスト用のクイズデータをセット
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'test_q1',
          question: 'テスト問題1',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          expBonusPercent: 30,
        ),
        const QuizQuestion(
          id: 'test_q2',
          question: 'テスト問題2',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 2,
          expBonusPercent: 20,
        ),
      ]);
    });

    test('drawQuizQuestion - 確率100%で必ず問題が返る', () {
      QuizService.probability = 1.0;
      final question = QuizService.drawQuizQuestion();
      expect(question, isNotNull);
      expect(question!.id, anyOf('test_q1', 'test_q2'));
    });

    test('drawQuizQuestion - 確率0%でnullが返る', () {
      QuizService.probability = 0.0;
      final question = QuizService.drawQuizQuestion();
      expect(question, isNull);
    });

    test('drawQuizQuestion - 問題が空の場合はnull', () {
      QuizService.setQuestions([]);
      QuizService.probability = 1.0;
      final question = QuizService.drawQuizQuestion();
      expect(question, isNull);
    });

    test('calcBonusExp - 30%ボーナスを正しく計算', () {
      final bonus = QuizService.calcBonusExp(30, 100);
      expect(bonus, 30);
    });

    test('calcBonusExp - 端数は四捨五入', () {
      final bonus = QuizService.calcBonusExp(33, 100);
      expect(bonus, 33);
    });

    test('calcBonusExp - 0%ボーナスは0', () {
      final bonus = QuizService.calcBonusExp(0, 100);
      expect(bonus, 0);
    });

    test('calcBonusExp - baseExpが0なら0', () {
      final bonus = QuizService.calcBonusExp(30, 0);
      expect(bonus, 0);
    });

    tearDown(() {
      // 確率をデフォルトに戻す
      QuizService.probability = 0.30;
    });
  });
}
