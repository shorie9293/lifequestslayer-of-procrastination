import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/guild/domain/task_time_record.dart';

/// 見積もり時間記録モデル（改善提案 #131）の試練。
void main() {
  final at = DateTime(2026, 10, 14, 9);

  group('TaskTimeRecord 検証', () {
    test('taskId 空で ArgumentError', () {
      expect(
        () => TaskTimeRecord(
          taskId: '',
          title: '討伐',
          estimatedMinutes: 30,
          actualMinutes: 40,
          recordedAt: at,
        ),
        throwsArgumentError,
      );
    });

    test('title 空で ArgumentError', () {
      expect(
        () => TaskTimeRecord(
          taskId: 't1',
          title: '',
          estimatedMinutes: 30,
          actualMinutes: 40,
          recordedAt: at,
        ),
        throwsArgumentError,
      );
    });

    test('estimatedMinutes 0 で ArgumentError', () {
      expect(
        () => TaskTimeRecord(
          taskId: 't1',
          title: '討伐',
          estimatedMinutes: 0,
          actualMinutes: 40,
          recordedAt: at,
        ),
        throwsArgumentError,
      );
    });

    test('estimatedMinutes 負で ArgumentError', () {
      expect(
        () => TaskTimeRecord(
          taskId: 't1',
          title: '討伐',
          estimatedMinutes: -5,
          actualMinutes: 40,
          recordedAt: at,
        ),
        throwsArgumentError,
      );
    });

    test('actualMinutes 0 で ArgumentError', () {
      expect(
        () => TaskTimeRecord(
          taskId: 't1',
          title: '討伐',
          estimatedMinutes: 30,
          actualMinutes: 0,
          recordedAt: at,
        ),
        throwsArgumentError,
      );
    });

    test('actualMinutes 負で ArgumentError', () {
      expect(
        () => TaskTimeRecord(
          taskId: 't1',
          title: '討伐',
          estimatedMinutes: 30,
          actualMinutes: -1,
          recordedAt: at,
        ),
        throwsArgumentError,
      );
    });

    test('正当な値で生成でき、既定 recordedAt は非null', () {
      final r = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 40,
      );
      expect(r.recordedAt, isNotNull);
    });
  });

  group('TaskTimeRecord id', () {
    test('id は taskId_マイクロ秒 の形式', () {
      final r = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 40,
        recordedAt: at,
      );
      expect(r.id, 't1_${at.microsecondsSinceEpoch}');
    });

    test('同一 taskId でも recordedAt が違えば id も違う', () {
      final a = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 40,
        recordedAt: at,
      );
      final b = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 40,
        recordedAt: at.add(const Duration(minutes: 1)),
      );
      expect(a.id, isNot(b.id));
    });
  });

  group('TaskTimeRecord JSON 往復', () {
    test('toJson → fromJson で値等価に復元できる', () {
      final r = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 42,
        recordedAt: at,
      );
      final back = TaskTimeRecord.fromJson(r.toJson());
      expect(back, r);
      expect(back.hashCode, r.hashCode);
    });

    test('fromJson で欠落キーは FormatException', () {
      final json = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 42,
        recordedAt: at,
      ).toJson()
        ..remove('estimatedMinutes');
      expect(() => TaskTimeRecord.fromJson(json), throwsFormatException);
    });

    test('fromJson で型不一致は FormatException', () {
      expect(
        () => TaskTimeRecord.fromJson({
          'taskId': 't1',
          'title': '討伐',
          'estimatedMinutes': '30',
          'actualMinutes': 42,
          'recordedAt': at.toIso8601String(),
        }),
        throwsFormatException,
      );
    });

    test('fromJson で不正日時は FormatException', () {
      expect(
        () => TaskTimeRecord.fromJson({
          'taskId': 't1',
          'title': '討伐',
          'estimatedMinutes': 30,
          'actualMinutes': 42,
          'recordedAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });

  group('TaskTimeRecord 値等価', () {
    test('同一フィールドは等価', () {
      final a = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 42,
        recordedAt: at,
      );
      final b = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 42,
        recordedAt: at,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('フィールドが1つでも違えば非等価', () {
      final a = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 42,
        recordedAt: at,
      );
      final b = TaskTimeRecord(
        taskId: 't1',
        title: '討伐',
        estimatedMinutes: 30,
        actualMinutes: 43,
        recordedAt: at,
      );
      expect(a, isNot(b));
    });
  });
}
