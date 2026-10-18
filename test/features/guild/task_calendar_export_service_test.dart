// クエスト期限カレンダー書き出しの選別・変換ロジック試練。

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/calendar_export/domain/task_calendar_export_service.dart';

Task _t(
  String id, {
  DateTime? deadline,
  bool isCompleted = false,
  DateTime? cancelledAt,
  String title = 'クエスト',
  QuestRank rank = QuestRank.B,
  int? targetTimeMinutes,
}) =>
    Task(
      id: id,
      title: title,
      deadline: deadline,
      isCompleted: isCompleted,
      cancelledAt: cancelledAt,
      rank: rank,
      targetTimeMinutes: targetTimeMinutes,
    );

final _now = DateTime(2026, 10, 19, 12, 0);

void main() {
  group('CalendarExportRange', () {
    test('4種の範囲とラベルを持つ', () {
      expect(CalendarExportRange.values.length, 4);
      expect(CalendarExportRange.all.label, 'すべて');
      expect(CalendarExportRange.withDeadline.label, '期限あり');
      expect(CalendarExportRange.next7Days.label, '7日以内');
      expect(CalendarExportRange.next30Days.label, '30日以内');
    });
  });

  group('selectTasks', () {
    test('完了・取消は常に除外し、all は期限なしも末尾に含む', () {
      final done =
          _t('done', deadline: DateTime(2026, 10, 20), isCompleted: true);
      final cancelled = _t('cancelled',
          deadline: DateTime(2026, 10, 21),
          cancelledAt: DateTime(2026, 10, 18));
      final noDeadline = _t('no_deadline');
      final dated = _t('dated', deadline: DateTime(2026, 10, 22));

      final result = TaskCalendarExportService.selectTasks(
        [done, cancelled, noDeadline, dated],
        CalendarExportRange.all,
        now: _now,
      );
      expect(result.map((t) => t.id).toList(), ['dated', 'no_deadline']);
    });

    test('withDeadline は期限なしを除外する', () {
      final result = TaskCalendarExportService.selectTasks(
        [_t('a'), _t('b', deadline: DateTime(2026, 11, 30))],
        CalendarExportRange.withDeadline,
        now: _now,
      );
      expect(result.map((t) => t.id).toList(), ['b']);
    });

    test('next7Days は当日と7日目を含み、8日目を除外する', () {
      final tasks = [
        _t('yesterday', deadline: DateTime(2026, 10, 18)),
        _t('today', deadline: DateTime(2026, 10, 19, 23, 59)),
        _t('day7', deadline: DateTime(2026, 10, 26)),
        _t('day8', deadline: DateTime(2026, 10, 27)),
        _t('none'),
      ];
      final result = TaskCalendarExportService.selectTasks(
        tasks,
        CalendarExportRange.next7Days,
        now: _now,
      );
      expect(result.map((t) => t.id).toList(), ['today', 'day7']);
    });

    test('next30Days は当日を含み31日目を除外する', () {
      final tasks = [
        _t('today', deadline: DateTime(2026, 10, 19)),
        _t('day30', deadline: DateTime(2026, 11, 18)),
        _t('day31', deadline: DateTime(2026, 11, 19)),
      ];
      final result = TaskCalendarExportService.selectTasks(
        tasks,
        CalendarExportRange.next30Days,
        now: _now,
      );
      expect(result.map((t) => t.id).toList(), ['today', 'day30']);
    });

    test('deadline 昇順 → id 昇順、期限なしは末尾', () {
      final tasks = [
        _t('z_none'),
        _t('b_same', deadline: DateTime(2026, 10, 25)),
        _t('a_same', deadline: DateTime(2026, 10, 25)),
        _t('early', deadline: DateTime(2026, 10, 20)),
        _t('a_none'),
      ];
      final result = TaskCalendarExportService.selectTasks(
        tasks,
        CalendarExportRange.all,
        now: _now,
      );
      expect(
        result.map((t) => t.id).toList(),
        ['early', 'a_same', 'b_same', 'a_none', 'z_none'],
      );
    });

    test('入力リストを変更しない', () {
      final tasks = [
        _t('b', deadline: DateTime(2026, 10, 25)),
        _t('a', deadline: DateTime(2026, 10, 20)),
      ];
      TaskCalendarExportService.selectTasks(
        tasks,
        CalendarExportRange.all,
        now: _now,
      );
      expect(tasks.map((t) => t.id).toList(), ['b', 'a']);
    });
  });

  group('buildEvents', () {
    test('期限ありのみを uid/summary/description 付きで変換する', () {
      final events = TaskCalendarExportService.buildEvents([
        _t('42',
            title: '城の討伐',
            deadline: DateTime(2026, 10, 25),
            rank: QuestRank.A,
            targetTimeMinutes: 30),
        _t('none'),
      ]);
      expect(events.length, 1);
      expect(events.single.uid, 'task-42@takamagahara');
      expect(events.single.summary, '城の討伐');
      expect(events.single.date, DateTime(2026, 10, 25));
      expect(events.single.description, 'ランク A / 見積 30分');
    });

    test('見積なしならランクのみ', () {
      final events = TaskCalendarExportService.buildEvents([
        _t('7', deadline: DateTime(2026, 10, 25), rank: QuestRank.S),
      ]);
      expect(events.single.description, 'ランク S');
    });
  });

  group('exportIcs', () {
    test('選別結果の SUMMARY が .ics に載る', () {
      final ics = TaskCalendarExportService.exportIcs(
        [
          _t('1', title: '討伐クエスト', deadline: DateTime(2026, 10, 20)),
          _t('2',
              title: '完了済み',
              deadline: DateTime(2026, 10, 21),
              isCompleted: true),
        ],
        CalendarExportRange.all,
        now: _now,
      );
      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('SUMMARY:討伐クエスト'));
      expect(ics, isNot(contains('SUMMARY:完了済み')));
      expect(ics, contains('UID:task-1@takamagahara'));
    });
  });
}
