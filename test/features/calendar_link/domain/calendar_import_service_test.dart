import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/calendar_link/domain/calendar_import_service.dart';
import 'package:rpg_todo/features/calendar_link/domain/linked_calendar_event.dart';

LinkedCalendarEvent _event({
  String id = 'e1',
  String title = '定例MTG',
  required DateTime start,
  DateTime? end,
  bool allDay = false,
}) {
  return LinkedCalendarEvent(
    eventId: id,
    calendarId: 'cal1',
    title: title,
    start: start,
    end: end ?? start.add(const Duration(minutes: 60)),
    allDay: allDay,
  );
}

void main() {
  final now = DateTime(2026, 11, 3, 9);

  group('selectCandidates', () {
    test('期間内の予定だけを開始順で返す', () {
      final events = <LinkedCalendarEvent>[
        _event(id: 'b', title: '夕会', start: DateTime(2026, 11, 3, 18)),
        _event(id: 'a', title: '朝会', start: DateTime(2026, 11, 3, 10)),
      ];

      final result = CalendarImportService.selectCandidates(
        events,
        now: now,
        range: CalendarImportRange.today,
      );

      expect(result.map((e) => e.title).toList(), <String>['朝会', '夕会']);
    });

    test('期間外（前日・期間末の翌日）は除外する', () {
      final events = <LinkedCalendarEvent>[
        _event(title: '昨日', start: DateTime(2026, 11, 2, 10)),
        _event(title: '3日目', start: DateTime(2026, 11, 5, 10)),
        _event(title: '4日目', start: DateTime(2026, 11, 6, 10)),
      ];

      final result = CalendarImportService.selectCandidates(
        events,
        now: now,
        range: CalendarImportRange.next3Days,
      );

      expect(result.map((e) => e.title), <String>['3日目']);
    });

    test('タイトルが空の予定は除外する', () {
      final events = <LinkedCalendarEvent>[
        _event(title: '   ', start: DateTime(2026, 11, 3, 10)),
        _event(title: '討伐', start: DateTime(2026, 11, 3, 11)),
      ];

      final result = CalendarImportService.selectCandidates(
        events,
        now: now,
        range: CalendarImportRange.today,
      );

      expect(result.single.title, '討伐');
    });

    test('既存クエストと題名＋日付が一致する予定は除外する（二重取り込み防止）', () {
      final existing = <Task>[
        Task(id: 't1', title: '定例MTG', deadline: DateTime(2026, 11, 3, 23, 59)),
      ];
      final events = <LinkedCalendarEvent>[
        _event(title: ' 定例MTG ', start: DateTime(2026, 11, 3, 10)),
        _event(id: 'e2', title: '別件', start: DateTime(2026, 11, 3, 15)),
      ];

      final result = CalendarImportService.selectCandidates(
        events,
        now: now,
        range: CalendarImportRange.today,
        existing: existing,
      );

      expect(result.map((e) => e.title), <String>['別件']);
    });

    test('取消済みクエストは重複判定に含めない（再取り込みを許す）', () {
      final existing = <Task>[
        Task(
          id: 't1',
          title: '定例MTG',
          deadline: DateTime(2026, 11, 3, 10),
          cancelledAt: DateTime(2026, 11, 3, 9, 30),
        ),
      ];
      final events = <LinkedCalendarEvent>[
        _event(title: '定例MTG', start: DateTime(2026, 11, 3, 10)),
      ];

      final result = CalendarImportService.selectCandidates(
        events,
        now: now,
        range: CalendarImportRange.today,
        existing: existing,
      );

      expect(result, hasLength(1));
    });

    test('予定同士が重複する場合は最初の1件だけ残す', () {
      final events = <LinkedCalendarEvent>[
        _event(id: 'e1', title: '定例MTG', start: DateTime(2026, 11, 3, 10)),
        _event(id: 'e2', title: '定例MTG', start: DateTime(2026, 11, 3, 16)),
      ];

      final result = CalendarImportService.selectCandidates(
        events,
        now: now,
        range: CalendarImportRange.today,
      );

      expect(result.single.eventId, 'e1');
    });
  });

  group('buildTask', () {
    test('時刻付き予定は開始時刻を期限にし、所要時間を見積にする', () {
      final event = _event(
        title: '  資料作成  ',
        start: DateTime(2026, 11, 3, 10),
        end: DateTime(2026, 11, 3, 11, 30),
      );

      final task = CalendarImportService.buildTask(event, id: 'q1');

      expect(task.id, 'q1');
      expect(task.title, '資料作成');
      expect(task.deadline, DateTime(2026, 11, 3, 10));
      expect(task.targetTimeMinutes, 90);
      expect(task.rank, QuestRank.S);
      expect(task.tags, contains(CalendarImportService.importTag));
      expect(task.status, TaskStatus.inGuild);
    });

    test('終日予定はその日の終わりを期限にし、見積は付けない', () {
      final event = _event(
        title: '休暇',
        start: DateTime(2026, 11, 3),
        end: DateTime(2026, 11, 4),
        allDay: true,
      );

      final task = CalendarImportService.buildTask(event, id: 'q2');

      expect(task.deadline, DateTime(2026, 11, 3, 23, 59));
      expect(task.targetTimeMinutes, isNull);
      expect(task.rank, QuestRank.B);
    });

    test('所要時間が5分未満なら見積を付けない', () {
      final event = _event(
        title: '確認',
        start: DateTime(2026, 11, 3, 10),
        end: DateTime(2026, 11, 3, 10, 3),
      );

      final task = CalendarImportService.buildTask(event, id: 'q3');

      expect(task.targetTimeMinutes, isNull);
      expect(task.rank, QuestRank.B);
    });

    test('終了が開始以前でも所要時間0として扱う（負値にしない）', () {
      final event = _event(
        title: '謎の予定',
        start: DateTime(2026, 11, 3, 10),
        end: DateTime(2026, 11, 3, 9),
      );

      expect(event.durationMinutes, 0);
      expect(CalendarImportService.buildTask(event, id: 'q4').targetTimeMinutes, isNull);
    });
  });

  group('rankFor', () {
    test('所要時間で S/A/B を決める', () {
      expect(CalendarImportService.rankFor(null), QuestRank.B);
      expect(CalendarImportService.rankFor(44), QuestRank.B);
      expect(CalendarImportService.rankFor(45), QuestRank.A);
      expect(CalendarImportService.rankFor(89), QuestRank.A);
      expect(CalendarImportService.rankFor(90), QuestRank.S);
    });
  });

  group('buildTasks', () {
    test('採番器を件数分だけ呼び、順序を保つ', () {
      var seq = 0;
      final events = <LinkedCalendarEvent>[
        _event(id: 'e1', title: 'A', start: DateTime(2026, 11, 3, 9)),
        _event(id: 'e2', title: 'B', start: DateTime(2026, 11, 3, 10)),
      ];

      final tasks = CalendarImportService.buildTasks(
        events,
        idGenerator: () => 'id-${seq++}',
      );

      expect(tasks.map((t) => t.id), <String>['id-0', 'id-1']);
      expect(tasks.map((t) => t.title), <String>['A', 'B']);
    });
  });

  group('dedupeKey', () {
    test('題名の空白差・大小差を吸収し、日付まで含める', () {
      final a = CalendarImportService.dedupeKey('  定例  MTG ', DateTime(2026, 11, 3, 10));
      final b = CalendarImportService.dedupeKey('定例 mtg', DateTime(2026, 11, 3, 23, 59));

      expect(a, b);
      expect(a, isNot(CalendarImportService.dedupeKey('定例 mtg', DateTime(2026, 11, 4))));
    });

    test('日付なしは空の日付部を持つ', () {
      expect(CalendarImportService.dedupeKey('A', null), 'a|');
    });
  });

  group('LinkedCalendarEvent', () {
    test('fromMap は epoch ミリ秒をローカル時刻へ戻す', () {
      final start = DateTime(2026, 11, 3, 10);
      final event = LinkedCalendarEvent.fromMap(<Object?, Object?>{
        'eventId': 42,
        'calendarId': 'cal',
        'title': '朝会',
        'startMillis': start.millisecondsSinceEpoch,
        'endMillis': start.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
        'allDay': false,
      });

      expect(event.eventId, '42');
      expect(event.start, start);
      expect(event.durationMinutes, 30);
    });

    test('toMap → fromMap で往復できる', () {
      final event = _event(title: '往復', start: DateTime(2026, 11, 3, 8));

      final restored = LinkedCalendarEvent.fromMap(event.toMap());

      expect(restored.title, '往復');
      expect(restored.start, event.start);
      expect(restored.end, event.end);
    });
  });
}
