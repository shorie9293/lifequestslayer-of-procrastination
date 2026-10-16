import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_streak.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  QuestStreakEntry entry({
    String taskId = 't1',
    String title = 'クエスト',
    int streak = 1,
    DateTime? last,
    int days = 0,
  }) {
    return QuestStreakEntry(
      taskId: taskId,
      title: title,
      currentStreak: streak,
      lastCompletedDate: last ?? d(2026, 10, 15),
      daysSinceLastCompletion: days,
    );
  }

  group('QuestStreakEntry 不変条件', () {
    test('taskId 空は ArgumentError', () {
      expect(
        () => entry(taskId: ''),
        throwsArgumentError,
      );
    });

    test('currentStreak < 1 は ArgumentError', () {
      expect(() => entry(streak: 0), throwsArgumentError);
      expect(() => entry(streak: -1), throwsArgumentError);
    });

    test('daysSinceLastCompletion < 0 は ArgumentError', () {
      expect(() => entry(days: -1), throwsArgumentError);
    });

    test('title 空・days=0 は許容', () {
      final e = entry(title: '', days: 0);
      expect(e.title, '');
    });
  });

  group('getter', () {
    test('isBonusActive 境界: 6→false, 7→true', () {
      expect(entry(streak: 6).isBonusActive, isFalse);
      expect(entry(streak: 7).isBonusActive, isTrue);
    });

    test('streakLabel / bonusLabel / lastCompletedLabel', () {
      final e = entry(streak: 7, last: d(2026, 1, 5));
      expect(e.streakLabel, '連続 7日');
      expect(e.bonusLabel, '+20% EXP');
      expect(e.lastCompletedLabel, '2026-01-05');

      final plain = entry(streak: 3);
      expect(plain.bonusLabel, '');
      expect(plain.lastCompletedLabel, '2026-10-15');
    });
  });

  group('QuestStreakService.build', () {
    test('daysSinceLastCompletion: 同日=0, 前日=1, 未来はクランプで0', () {
      final tasks = [Task(id: 'a', title: 'A'), Task(id: 'b', title: 'B')];
      final streaks = {
        'a': TaskStreak(currentStreak: 2, lastCompletedDate: d(2026, 10, 16)),
        'b': TaskStreak(currentStreak: 1, lastCompletedDate: d(2026, 10, 15)),
      };
      final entries = QuestStreakService.build(
        tasks: tasks,
        streaks: streaks,
        now: d(2026, 10, 16),
      );
      final byId = {for (final e in entries) e.taskId: e};
      expect(byId['a']!.daysSinceLastCompletion, 0);
      expect(byId['b']!.daysSinceLastCompletion, 1);
    });

    test('streak 無し task は除外', () {
      final tasks = [Task(id: 'a', title: 'A'), Task(id: 'b', title: 'B')];
      final entries = QuestStreakService.build(
        tasks: tasks,
        streaks: {
          'a': TaskStreak(currentStreak: 1, lastCompletedDate: d(2026, 10, 15)),
        },
        now: d(2026, 10, 16),
      );
      expect(entries.length, 1);
      expect(entries.first.taskId, 'a');
    });

    test('未知 taskId の streak は除外', () {
      final entries = QuestStreakService.build(
        tasks: [Task(id: 'a', title: 'A')],
        streaks: {
          'a': TaskStreak(currentStreak: 1, lastCompletedDate: d(2026, 10, 15)),
          'ghost':
              TaskStreak(currentStreak: 9, lastCompletedDate: d(2026, 10, 15)),
        },
        now: d(2026, 10, 16),
      );
      expect(entries.length, 1);
      expect(entries.first.taskId, 'a');
    });

    test('lastCompletedDate が now より未来の日付でも 0 にクランプ', () {
      final entries = QuestStreakService.build(
        tasks: [Task(id: 'a', title: 'A')],
        streaks: {
          'a': TaskStreak(currentStreak: 1, lastCompletedDate: d(2026, 10, 20)),
        },
        now: d(2026, 10, 16),
      );
      expect(entries.first.daysSinceLastCompletion, 0);
    });
  });

  group('sortEntries', () {
    test('currentStreak 降順 → title 昇順 → taskId 昇順', () {
      final a = entry(taskId: 'a', title: 'B', streak: 3);
      final b = entry(taskId: 'b', title: 'A', streak: 5);
      final c = entry(taskId: 'c', title: 'A', streak: 5);
      final sorted = QuestStreakService.sortEntries([a, b, c]);
      expect(sorted.map((e) => e.taskId).toList(), ['b', 'c', 'a']);
    });

    test('全タイでも決定的（taskId の昇順になる）', () {
      final x = entry(taskId: 'x', title: '同じ', streak: 2);
      final y = entry(taskId: 'y', title: '同じ', streak: 2);
      final z = entry(taskId: 'z', title: '同じ', streak: 2);
      final forward = QuestStreakService.sortEntries([z, x, y]);
      final backward = QuestStreakService.sortEntries([y, z, x]);
      final ids = ['x', 'y', 'z'];
      expect(forward.map((e) => e.taskId).toList(), ids);
      expect(backward.map((e) => e.taskId).toList(), ids);
    });

    test('非破壊（元リストを変更しない）', () {
      final a = entry(taskId: 'a', streak: 1);
      final b = entry(taskId: 'b', streak: 2);
      final original = [a, b];
      QuestStreakService.sortEntries(original);
      expect(original[0].taskId, 'a');
    });
  });

  group('summarize', () {
    test('空は全て 0', () {
      final s = QuestStreakService.summarize([]);
      expect(s.trackedCount, 0);
      expect(s.longestStreak, 0);
      expect(s.bonusActiveCount, 0);
      expect(s.longestStreakLabel, '記録なし');
      expect(s.bonusActiveLabel, 'ボーナス中 0件');
    });

    test('最長は最大値、ボーナス件数を数える', () {
      final s = QuestStreakService.summarize([
        entry(taskId: 'a', streak: 3),
        entry(taskId: 'b', streak: 9),
        entry(taskId: 'c', streak: 7),
      ]);
      expect(s.trackedCount, 3);
      expect(s.longestStreak, 9);
      expect(s.bonusActiveCount, 2);
      expect(s.longestStreakLabel, '最長 9日');
      expect(s.bonusActiveLabel, 'ボーナス中 2件');
    });
  });

  group('filterBonusActive', () {
    test('ボーナス中のみ残る', () {
      final result = QuestStreakService.filterBonusActive([
        entry(taskId: 'a', streak: 6),
        entry(taskId: 'b', streak: 7),
        entry(taskId: 'c', streak: 20),
      ]);
      expect(result.map((e) => e.taskId).toList(), ['b', 'c']);
    });
  });

  group('searchByTitle', () {
    test('全角英数・全角スペースを正規化して部分一致', () {
      final e1 = entry(taskId: 'a', title: 'ＲＵＮ　１０ｋｍ');
      final e2 = entry(taskId: 'b', title: '読書');
      final result = QuestStreakService.searchByTitle([e1, e2], 'run 10km');
      expect(result.map((e) => e.taskId).toList(), ['a']);
    });

    test('大文字小文字を無視', () {
      final e = entry(taskId: 'a', title: 'Morning Run');
      expect(
        QuestStreakService.searchByTitle([e], 'MORNING'),
        hasLength(1),
      );
    });

    test('空 query は全件', () {
      final list = [entry(taskId: 'a'), entry(taskId: 'b')];
      expect(QuestStreakService.searchByTitle(list, ''), hasLength(2));
      expect(QuestStreakService.searchByTitle(list, '  '), hasLength(2));
    });

    test('マッチしなければ 0 件', () {
      final result = QuestStreakService.searchByTitle(
        [entry(taskId: 'a', title: '読書')],
        'ランニング',
      );
      expect(result, isEmpty);
    });
  });
}
