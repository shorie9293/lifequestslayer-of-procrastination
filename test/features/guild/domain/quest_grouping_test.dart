import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_grouping.dart';

Task _task(
  String id, {
  String? title,
  QuestRank rank = QuestRank.B,
  DateTime? deadline,
  int? estimate,
}) =>
    Task(
      id: id,
      title: title ?? 'Q$id',
      rank: rank,
      deadline: deadline,
      targetTimeMinutes: estimate,
    );

void main() {
  // 2026-11-20 は金曜日。週の終わりは 11/22（日）。
  final friday = DateTime(2026, 11, 20, 10);

  group('期限パネル', () {
    test('今日・明日・今週・それ以降・期限なしに分かれる', () {
      final groups = groupQuests(
        [
          _task('t', deadline: DateTime(2026, 11, 20, 23, 59)),
          _task('m', deadline: DateTime(2026, 11, 21, 9)),
          _task('w', deadline: DateTime(2026, 11, 22, 20)),
          _task('l', deadline: DateTime(2026, 11, 25, 9)),
          _task('n'),
        ],
        mode: QuestGroupMode.deadline,
        now: friday,
      );

      expect(groups.map((g) => g.band).toList(), [
        QuestGroupBand.today,
        QuestGroupBand.tomorrow,
        QuestGroupBand.thisWeek,
        QuestGroupBand.later,
        QuestGroupBand.none,
      ]);
      expect(groups.first.label, '今日（11/20）');
      expect(groups[1].label, '明日（11/21）');
      expect(groups[2].label, '今週（〜11/22）');
      expect(groups.last.label, '期限なし');
    });

    test('期限切れは最上段に「期限切れ」として出す', () {
      final groups = groupQuests(
        [
          _task('late', deadline: DateTime(2026, 11, 18, 9)),
          _task('t', deadline: DateTime(2026, 11, 20, 23)),
        ],
        mode: QuestGroupMode.deadline,
        now: friday,
      );
      expect(groups.first.band, QuestGroupBand.overdue);
      expect(groups.first.label, '期限切れ');
      expect(groups.first.tasks.single.id, 'late');
    });

    test('空のパネルは返さない', () {
      final groups = groupQuests(
        [_task('n')],
        mode: QuestGroupMode.deadline,
        now: friday,
      );
      expect(groups.length, 1);
      expect(groups.single.band, QuestGroupBand.none);
    });

    test('パネル内は期限の昇順、期限なしはランクの重い順', () {
      final groups = groupQuests(
        [
          _task('b2', deadline: DateTime(2026, 11, 25, 9)),
          _task('b1', deadline: DateTime(2026, 11, 24, 9)),
          _task('nA', rank: QuestRank.A),
          _task('nB', rank: QuestRank.B),
        ],
        mode: QuestGroupMode.deadline,
        now: friday,
      );
      final later = groups.firstWhere((g) => g.band == QuestGroupBand.later);
      expect(later.tasks.map((t) => t.id).toList(), ['b1', 'b2']);
      final none = groups.firstWhere((g) => g.band == QuestGroupBand.none);
      expect(none.tasks.map((t) => t.id).toList(), ['nA', 'nB']);
    });

    test('日曜は今日が週末（今週パネルは出ない）', () {
      final sunday = DateTime(2026, 11, 22, 8);
      final groups = groupQuests(
        [
          _task('t', deadline: DateTime(2026, 11, 22, 23)),
          _task('l', deadline: DateTime(2026, 11, 23, 9)),
        ],
        mode: QuestGroupMode.deadline,
        now: sunday,
      );
      // 翌日は「明日」、その先は「それ以降」。週末パネルは空なので出ない。
      expect(groups.map((g) => g.band).toList(),
          [QuestGroupBand.today, QuestGroupBand.tomorrow]);
    });
  });

  group('ランクパネル', () {
    test('S→A→B の順に束ね、空のランクは出さない', () {
      final groups = groupQuests(
        [
          _task('b', rank: QuestRank.B),
          _task('s', rank: QuestRank.S),
          _task('b2', rank: QuestRank.B),
        ],
        mode: QuestGroupMode.rank,
        now: friday,
      );
      expect(groups.map((g) => g.label).toList(), ['S 級', 'B 級']);
      expect(groups.first.count, 1);
      expect(groups.last.count, 2);
    });
  });

  group('見出しの補足', () {
    test('見積の合計を h/m 表記にする', () {
      final groups = groupQuests(
        [
          _task('a', deadline: DateTime(2026, 11, 20, 12), estimate: 90),
          _task('b', deadline: DateTime(2026, 11, 20, 18), estimate: 60),
          _task('c', deadline: DateTime(2026, 11, 20, 19)),
        ],
        mode: QuestGroupMode.deadline,
        now: friday,
      );
      final today = groups.first;
      expect(today.totalEstimateMinutes, 150);
      expect(today.estimateLabel, '2h30m');
      expect(today.rankBreakdown, 'B3');
      expect(today.summary, 'B3 ・ 2h30m');
    });

    test('見積ゼロは — と表示する', () {
      final groups = groupQuests([_task('a')], mode: QuestGroupMode.rank, now: friday);
      expect(groups.single.estimateLabel, '—');
      expect(formatEstimate(0), '—');
      expect(formatEstimate(45), '45分');
      expect(formatEstimate(120), '2h');
    });
  });
}
