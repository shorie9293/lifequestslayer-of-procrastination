import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_snooze_service.dart';

void main() {
  const service = QuestSnoozeService();

  Task taskWith({
    String id = 't1',
    DateTime? deadline,
    bool isCompleted = false,
  }) {
    return Task(
      id: id,
      title: '試練のクエスト',
      status: TaskStatus.active,
      isCompleted: isCompleted,
      deadline: deadline,
    );
  }

  group('定数・ラベル', () {
    test('actionLabel は 微睡みの加護（+1日）', () {
      expect(service.actionLabel, '微睡みの加護（+1日）');
    });

    test('snoozeDuration はちょうど1日', () {
      expect(QuestSnoozeService.snoozeDuration, const Duration(days: 1));
    });
  });

  group('canSnooze', () {
    test('期限ありの未完了クエストはスヌーズ可能', () {
      final task = taskWith(deadline: DateTime(2026, 10, 21, 21, 0));
      expect(service.canSnooze(task), isTrue);
    });

    test('期限が null ならスヌーズ不可', () {
      final task = taskWith();
      expect(service.canSnooze(task), isFalse);
    });

    test('討伐済みなら期限があってもスヌーズ不可', () {
      final task = taskWith(
        deadline: DateTime(2026, 10, 21, 21, 0),
        isCompleted: true,
      );
      expect(service.canSnooze(task), isFalse);
    });
  });

  group('blockReason', () {
    test('期限ありなら null', () {
      final task = taskWith(deadline: DateTime(2026, 10, 21, 21, 0));
      expect(service.blockReason(task), isNull);
    });

    test('期限 null なら理由文言を返す', () {
      final task = taskWith();
      expect(service.blockReason(task), isNotNull);
      expect(service.blockReason(task), '期限が無いため微睡めません');
    });

    test('討伐済みなら理由文言を返す', () {
      final task = taskWith(
        deadline: DateTime(2026, 10, 21, 21, 0),
        isCompleted: true,
      );
      expect(service.blockReason(task), isNotNull);
    });
  });

  group('extendedDeadline', () {
    test('ちょうど1日後を返す', () {
      final task = taskWith(deadline: DateTime(2026, 10, 21, 21, 0));
      expect(
        service.extendedDeadline(task),
        equals(DateTime(2026, 10, 22, 21, 0)),
      );
      expect(
        service.extendedDeadline(task)!.difference(task.deadline!),
        const Duration(days: 1),
      );
    });

    test('期限 null なら null', () {
      final task = taskWith();
      expect(service.extendedDeadline(task), isNull);
    });

    test('元の task.deadline を破壊しない', () {
      final original = DateTime(2026, 10, 21, 21, 0);
      final task = taskWith(deadline: original);

      service.extendedDeadline(task);

      expect(task.deadline, equals(original));
      expect(task.deadline, same(original));
    });

    test('月をまたぐ場合も暦どおり加算する', () {
      final task = taskWith(deadline: DateTime(2026, 10, 31, 23, 30));
      expect(
        service.extendedDeadline(task),
        equals(DateTime(2026, 11, 1, 23, 30)),
      );
    });
  });

  group('isSnoozed / snoozedAt', () {
    test('記録があれば isSnoozed は true', () {
      final map = {'t1': DateTime(2026, 10, 21, 8, 0)};
      expect(service.isSnoozed(map, 't1'), isTrue);
    });

    test('記録が無い・未知IDなら isSnoozed は false', () {
      final map = {'t1': DateTime(2026, 10, 21, 8, 0)};
      expect(service.isSnoozed(map, 't2'), isFalse);
      expect(service.isSnoozed(<String, DateTime>{}, 't1'), isFalse);
    });

    test('snoozedAt は記録済み日時を返す', () {
      final at = DateTime(2026, 10, 21, 8, 0);
      final map = {'t1': at};
      expect(service.snoozedAt(map, 't1'), equals(at));
    });

    test('snoozedAt は未知IDなら null', () {
      final map = {'t1': DateTime(2026, 10, 21, 8, 0)};
      expect(service.snoozedAt(map, 't9'), isNull);
    });
  });

  group('countSnoozed', () {
    test('実在するIDのみ数え、幽霊IDは数えない', () {
      final tasks = [
        taskWith(id: 't1'),
        taskWith(id: 't2'),
        taskWith(id: 't3'),
      ];
      final map = {
        't1': DateTime(2026, 10, 21, 8, 0),
        't3': DateTime(2026, 10, 22, 8, 0),
        'ghost': DateTime(2026, 10, 23, 8, 0),
      };
      expect(service.countSnoozed(tasks, map), 2);
    });

    test('記録が空なら 0', () {
      final tasks = [taskWith(id: 't1')];
      expect(service.countSnoozed(tasks, <String, DateTime>{}), 0);
    });
  });

  group('snoozedTasksOf', () {
    test('tasks の入力順を保持する', () {
      final tasks = [
        taskWith(id: 'c'),
        taskWith(id: 'a'),
        taskWith(id: 'b'),
      ];
      final map = {
        'a': DateTime(2026, 10, 21),
        'b': DateTime(2026, 10, 21),
        'c': DateTime(2026, 10, 21),
      };
      expect(
        service.snoozedTasksOf(tasks, map).map((t) => t.id).toList(),
        equals(<String>['c', 'a', 'b']),
      );
    });

    test('幽霊IDは含まない', () {
      final tasks = [taskWith(id: 't1'), taskWith(id: 't2')];
      final map = {
        't1': DateTime(2026, 10, 21, 8, 0),
        'ghost': DateTime(2026, 10, 21, 8, 0),
      };
      expect(
        service.snoozedTasksOf(tasks, map).map((t) => t.id).toList(),
        equals(<String>['t1']),
      );
    });

    test('記録が空なら空リスト', () {
      final tasks = [taskWith(id: 't1')];
      expect(
        service.snoozedTasksOf(tasks, <String, DateTime>{}),
        isEmpty,
      );
    });
  });

  group('confirmMessage', () {
    test('期限 10/21 21:00 → 10/22 21:00 の文言を含む', () {
      final task = taskWith(deadline: DateTime(2026, 10, 21, 21, 0));
      final message = service.confirmMessage(task);
      expect(message, contains('10/21 21:00 → 10/22 21:00'));
      expect(message, '期限 10/21 21:00 → 10/22 21:00 に延ばしますか？');
    });

    test('時分は2桁ゼロ埋め・月日はゼロ埋めしない', () {
      final task = taskWith(deadline: DateTime(2026, 1, 5, 9, 5));
      expect(service.confirmMessage(task), contains('1/5 09:05 → 1/6 09:05'));
    });

    test('期限 null なら 期限が無いため微睡めません', () {
      final task = taskWith();
      expect(service.confirmMessage(task), '期限が無いため微睡めません');
    });
  });

  group('badgeLabel', () {
    test('スヌーズ済みなら 微睡み M/d 形式', () {
      final map = {'t1': DateTime(2026, 10, 21, 8, 30)};
      expect(service.badgeLabel(map, 't1'), '微睡み 10/21');
    });

    test('未スヌーズなら null', () {
      final map = {'t1': DateTime(2026, 10, 21, 8, 30)};
      expect(service.badgeLabel(map, 't2'), isNull);
      expect(service.badgeLabel(<String, DateTime>{}, 't1'), isNull);
    });
  });
}
