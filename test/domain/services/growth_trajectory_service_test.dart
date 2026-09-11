import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/growth_trajectory_service.dart';

void main() {
  // 基準日時（決定論的）。2026-09-15 12:00
  final now = DateTime(2026, 9, 15, 12, 0);

  Task task({String? id, DateTime? completedAt}) => Task(
        id: id ?? 't_${completedAt?.millisecondsSinceEpoch ?? 0}',
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

  group('GrowthTrajectoryService.compute', () {
    test('空データは12か月分の0バケット・全指標ゼロ', () {
      final g = GrowthTrajectoryService.compute(
        tasks: const [],
        reflections: const [],
        now: now,
      );
      expect(g.points.length, 12);
      expect(g.points.every((p) => p.isEmpty), isTrue);
      expect(g.isEmpty, isTrue);
      expect(g.totalQuestsCompleted, 0);
      expect(g.totalDefeats, 0);
      expect(g.activeMonths, 0);
      expect(g.longestActiveStreak, 0);
      expect(g.bestMonth, isNull);
      expect(g.windowQuestsCompleted, 0);
      expect(g.windowDefeats, 0);
    });

    test('months が1未満なら ArgumentError', () {
      expect(
        () => GrowthTrajectoryService.compute(
          tasks: const [],
          reflections: const [],
          now: now,
          months: 0,
        ),
        throwsArgumentError,
      );
    });

    test('窓は古い順で、最後の月が now の年月になる', () {
      final g = GrowthTrajectoryService.compute(
        tasks: const [],
        reflections: const [],
        now: now,
        months: 3,
      );
      expect(g.points.map((p) => '${p.year}-${p.month}').toList(),
          ['2026-7', '2026-8', '2026-9']);
    });

    test('勤行完了数と討伐勝利数を月別に集計する', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [
          task(completedAt: DateTime(2026, 8, 1)),
          task(completedAt: DateTime(2026, 8, 20)),
          task(completedAt: DateTime(2026, 9, 2)),
        ],
        reflections: [refl(DateTime(2026, 9, 3))],
        now: now,
        months: 3,
      );
      final aug = g.points[1];
      final sep = g.points[2];
      expect(aug.questsCompleted, 2);
      expect(aug.defeats, 0);
      expect(sep.questsCompleted, 1);
      expect(sep.defeats, 1);
      expect(g.windowQuestsCompleted, 3);
      expect(g.windowDefeats, 1);
      expect(g.totalQuestsCompleted, 3);
    });

    test('累積値は窓の外の過去も含めて算出される', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [
          // 窓（直近3か月）より前の完了2件
          task(completedAt: DateTime(2026, 3, 10)),
          task(completedAt: DateTime(2026, 4, 10)),
          // 窓内の完了1件
          task(completedAt: DateTime(2026, 8, 10)),
        ],
        reflections: const [],
        now: now,
        months: 3,
      );
      expect(g.windowQuestsCompleted, 1);
      expect(g.totalQuestsCompleted, 3);
      // 窓の先頭月（7月）時点で既に過去2件が累積に載る
      expect(g.points.first.cumulativeQuests, 2);
      expect(g.points.last.cumulativeQuests, 3);
    });

    test('未来日付の記録は無視される', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [
          task(completedAt: DateTime(2026, 12, 1)),
          task(completedAt: DateTime(2026, 9, 1)),
        ],
        reflections: [refl(DateTime(2026, 11, 1))],
        now: now,
        months: 3,
      );
      expect(g.totalQuestsCompleted, 1);
      expect(g.totalDefeats, 0);
      expect(g.points.last.cumulativeQuests, 1);
    });

    test('未完了（lastCompletedAt が null）のクエストは数えない', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [task(), task(completedAt: DateTime(2026, 9, 5))],
        reflections: const [],
        now: now,
      );
      expect(g.totalQuestsCompleted, 1);
      expect(g.points.last.questsCompleted, 1);
    });

    test('活動の連続月数（最長）を算出する', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [
          task(completedAt: DateTime(2026, 7, 5)),
          task(completedAt: DateTime(2026, 8, 5)),
          task(completedAt: DateTime(2026, 9, 5)),
        ],
        reflections: const [],
        now: now,
        months: 6,
      );
      // 3月〜6月は活動なし、7〜9月が3連続
      expect(g.longestActiveStreak, 3);
      expect(g.activeMonths, 3);
    });

    test('最活動月（bestMonth）は活動量最大・同点なら新しい月', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [
          task(completedAt: DateTime(2026, 8, 1)),
          task(completedAt: DateTime(2026, 9, 1)),
          task(completedAt: DateTime(2026, 9, 2)),
        ],
        reflections: [refl(DateTime(2026, 9, 2))],
        now: now,
        months: 3,
      );
      expect(g.bestMonth, isNotNull);
      expect(g.bestMonth!.month, 9);
      expect(g.bestMonth!.activity, 3);
    });

    test('年をまたぐ窓でも正しく月を遡る', () {
      final g = GrowthTrajectoryService.compute(
        tasks: const [],
        reflections: const [],
        now: DateTime(2026, 2, 10),
        months: 4,
      );
      expect(g.points.map((p) => '${p.year}-${p.month}').toList(),
          ['2025-11', '2025-12', '2026-1', '2026-2']);
    });

    test('月次ポイントのラベルと活動量ゲッター', () {
      final g = GrowthTrajectoryService.compute(
        tasks: [task(completedAt: DateTime(2026, 9, 1))],
        reflections: const [],
        now: now,
        months: 1,
      );
      expect(g.points.single.label, '9月');
      expect(g.points.single.activity, 1);
      expect(g.points.single.isEmpty, isFalse);
    });
  });
}
