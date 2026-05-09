import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';

void main() {
  group('期限切れデバッグ', () {
    test('deadlineの比較が正しく動作する', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 1));
      final future = now.add(const Duration(days: 1));
      
      expect(past.isBefore(now), isTrue, reason: '過去の日付は現在より前');
      expect(future.isBefore(now), isFalse, reason: '未来の日付は現在より前ではない');
      expect((DateTime(2020, 1, 1)).isBefore(now), isTrue, reason: '固定過去日付は現在より前');
    });

    test('deadlineがnullのタスクでisOverdueがfalseになる', () {
      final task = Task(
        id: 'test-1',
        title: 'テスト',
        deadline: null,
      );
      final isOverdue = task.deadline != null && task.deadline!.isBefore(DateTime.now());
      expect(isOverdue, isFalse);
    });

    test('deadlineが過去のタスクでisOverdueがtrueになる', () {
      final task = Task(
        id: 'test-2',
        title: 'テスト',
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      );
      print('DEADLINE: ${task.deadline}');
      print('NOW: ${DateTime.now()}');
      print('isBefore: ${task.deadline!.isBefore(DateTime.now())}');
      final isOverdue = task.deadline != null && task.deadline!.isBefore(DateTime.now());
      expect(isOverdue, isTrue, reason: 'deadlineが過去ならisOverdueはtrue');
    });

    test('TaskCompletionServiceで期限切れが正しく検出される', () {
      QuizService.setQuestions([
        const QuizQuestion(id: 'q1', question: 'Q1?', choices: ['A','B','C','D'], correctIndex: 0, expBonusPercent: 30),
      ]);
      QuizService.probability = 0.0;

      final service = TaskCompletionService();
      final task = Task(
        id: 'test-3',
        title: '期限切れタスク',
        status: TaskStatus.active,
        deadline: DateTime.now().subtract(const Duration(days: 2)),
      );
      final player = Player();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: true,
      );

      expect(result, isNotNull);
      print('RESULT quizQuestion: ${result!.quizQuestion}');
      print('RESULT bonusMessages: ${result.bonusMessages}');
      print('RESULT expGain: ${result.expGain}');
      expect(result.quizQuestion, isNotNull, reason: '期限切れタスクのクイズはnon-null');
      expect(result.bonusMessages, anyElement(contains('期限切れ')),
          reason: '期限切れメッセージが含まれるべき');
      expect(result.expGain, lessThan(100), reason: 'EXPが減少しているべき');
    });
  });
}
