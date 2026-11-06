import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';

/// レアドロップの当落だけを固定する Random。
class _FixedDoubleRandom implements Random {
  _FixedDoubleRandom(this.value);
  final double value;

  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('親探針: 期限切れコイン半減はレアドロップの当落で 15/90 に分岐する', () {
    setUp(() {
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'hard_q1',
          question: '難しい問題',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 3,
          expBonusPercent: 50,
        ),
      ]);
      QuizService.probability = 0.0;
    });

    tearDown(() {
      QuizService.probability = 0.30;
    });

    Task overdueTask() => Task(
          id: 'overdue-coin-penalty',
          title: 'テストクエスト',
          status: TaskStatus.active,
          rank: QuestRank.A,
          deadline: DateTime.now().subtract(const Duration(hours: 2)),
        );

    int coinsWith(double draw) {
      final service = TaskCompletionService(rng: _FixedDoubleRandom(draw));
      final player = Player();
      player.jobLevels[player.currentJob] = 1;
      final result = service.complete(
        task: overdueTask(),
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );
      return result!.coinsGained;
    }

    test('レアドロップ当選（nextDouble=0.0）なら 30 + 150 を半減して 90 文になる', () {
      expect(coinsWith(0.0), equals(90));
    });

    test('レアドロップ落選（nextDouble=0.99）なら Aランク30 を半減して 15 文になる', () {
      expect(coinsWith(0.99), equals(15));
    });

    test('落選する Random を注入すれば何度撃っても 15 文で安定する（決定化）', () {
      for (var i = 0; i < 5; i++) {
        expect(coinsWith(0.99), equals(15), reason: '$i 回目');
      }
    });
  });
}
