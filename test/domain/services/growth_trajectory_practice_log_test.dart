import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/growth_trajectory_service.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12, 0);

  Task task(DateTime? completedAt, {String id = 't1'}) => Task(
        id: id,
        title: 'quest',
        lastCompletedAt: completedAt,
      );

  Reflection refl(DateTime date) => Reflection(
        id: 'r_${date.millisecondsSinceEpoch}',
        taskId: 't1',
        date: date,
        content: 'content',
        selfDifficulty: 3,
        aiDifficulty: QuestRank.A,
        sentiment: 'kaishin',
      );

  PracticeLog log(DateTime date, int count) =>
      PracticeLog(date: date, count: count);

  group('GrowthTrajectoryService + 日別履歴ログ（#50）', () {
    test('ログが無ければ従来通り lastCompletedAt から集計する（後方互換）', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [task(DateTime(2026, 9, 10))],
        reflections: const [],
        now: now,
      );
      expect(g.totalQuestsCompleted, 1);
      expect(g.points.last.questsCompleted, 1);
    });

    test('ログがあれば同日複数回の完遂も回数として集計する', () {
      final g = GrowthTrajectoryService.compute(
        tasks: const [],
        reflections: const [],
        now: now,
        practiceLogs: [log(DateTime(2026, 9, 10), 3)],
      );
      expect(g.totalQuestsCompleted, 3);
      expect(g.points.last.questsCompleted, 3);
    });

    test('ログに無い日は旧来の lastCompletedAt で補完する（履歴を失わない）', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [task(DateTime(2026, 8, 20), id: 'a')],
        reflections: const [],
        now: now,
        practiceLogs: [log(DateTime(2026, 9, 10), 2)],
      );
      expect(g.totalQuestsCompleted, 3); // 8/20 の1件 + 9/10 の2件
      expect(g.points.last.questsCompleted, 2);
    });

    test('ログのある日の lastCompletedAt は二重計上しない', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [task(DateTime(2026, 9, 10, 9))],
        reflections: const [],
        now: now,
        practiceLogs: [log(DateTime(2026, 9, 10), 2)],
      );
      expect(g.totalQuestsCompleted, 2);
    });

    test('討伐勝利数は従来通り振り返りから集計する', () {
      final g = GrowthTrajectoryService.compute(
        tasks: const [],
        reflections: [refl(DateTime(2026, 9, 12))],
        now: now,
        practiceLogs: [log(DateTime(2026, 9, 10), 1)],
      );
      expect(g.totalDefeats, 1);
      expect(g.totalQuestsCompleted, 1);
    });

    test('未来日付のログは集計から除外される', () {
      final g = GrowthTrajectoryService.compute(
        tasks: const [],
        reflections: const [],
        now: now,
        practiceLogs: [
          log(DateTime(2026, 9, 10), 1),
          log(DateTime(2026, 10, 1), 5),
        ],
      );
      expect(g.totalQuestsCompleted, 1);
    });

    test('months 未満の値は ArgumentError のまま', () {
      expect(
        () => GrowthTrajectoryService.compute(
          tasks: const [],
          reflections: const [],
          now: now,
          months: 0,
          practiceLogs: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}
