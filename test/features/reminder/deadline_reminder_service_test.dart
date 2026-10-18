import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_service.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';

/// ローカル時刻で日付を組む（TZ=UTC でも同じ日付成分になる＝時限爆弾なし）。
Task _task(
  String id,
  DateTime? deadline, {
  String? title,
  bool isCompleted = false,
  DateTime? cancelledAt,
}) {
  return Task(
    id: id,
    title: title ?? 'クエスト$id',
    deadline: deadline,
    isCompleted: isCompleted,
    cancelledAt: cancelledAt,
  );
}

void main() {
  final service = const DeadlineReminderService();
  final now = DateTime(2026, 10, 18, 9, 0);

  group('selectUpcoming', () {
    test('当日・翌日・範囲内の締切を抽出し、範囲外は除外する', () {
      final tasks = [
        _task('today', DateTime(2026, 10, 18, 23, 59, 59)),
        _task('tomorrow', DateTime(2026, 10, 19, 12, 0)),
        _task('day2', DateTime(2026, 10, 20, 9, 0)),
        _task('day3', DateTime(2026, 10, 21, 9, 0)), // 3日以内の範囲外
        _task('yesterday', DateTime(2026, 10, 17, 23, 59, 59)),
      ];
      final selected = service.selectUpcoming(tasks, now, withinDays: 3);
      expect(selected.map((t) => t.id), ['today', 'tomorrow', 'day2']);
    });

    test('withinDays=1 は当日のみ', () {
      final tasks = [
        _task('today', DateTime(2026, 10, 18, 23, 59, 59)),
        _task('tomorrow', DateTime(2026, 10, 19, 0, 0)),
      ];
      final selected = service.selectUpcoming(tasks, now, withinDays: 1);
      expect(selected.map((t) => t.id), ['today']);
    });

    test('当日0:00の締切も当日として拾う', () {
      final tasks = [_task('midnight', DateTime(2026, 10, 18, 0, 0))];
      expect(service.selectUpcoming(tasks, now, withinDays: 1).length, 1);
    });

    test('完了済み・取消済み・期限なしは除外する', () {
      final tasks = [
        _task('done', DateTime(2026, 10, 18, 12, 0), isCompleted: true),
        _task('cancelled', DateTime(2026, 10, 18, 12, 0),
            cancelledAt: DateTime(2026, 10, 17, 12, 0)),
        _task('noDeadline', null),
      ];
      expect(service.selectUpcoming(tasks, now, withinDays: 3), isEmpty);
    });

    test('期限昇順・同時刻は id 昇順で安定ソートする', () {
      final tasks = [
        _task('b', DateTime(2026, 10, 19, 12, 0)),
        _task('a', DateTime(2026, 10, 19, 12, 0)),
        _task('c', DateTime(2026, 10, 18, 18, 0)),
      ];
      final selected = service.selectUpcoming(tasks, now, withinDays: 3);
      expect(selected.map((t) => t.id), ['c', 'a', 'b']);
    });

    test('入力を破壊しない', () {
      final tasks = [
        _task('b', DateTime(2026, 10, 19, 12, 0)),
        _task('a', DateTime(2026, 10, 18, 12, 0)),
      ];
      service.selectUpcoming(tasks, now, withinDays: 3);
      expect(tasks.map((t) => t.id), ['b', 'a']);
    });

    test('withinDays が 0 以下なら ArgumentError', () {
      expect(
        () => service.selectUpcoming(const [], now, withinDays: 0),
        throwsArgumentError,
      );
    });
  });

  group('bucketOf / bucketLabel', () {
    test('当日・翌日・それ以降を区別する', () {
      expect(
        service.bucketOf(_task('a', DateTime(2026, 10, 18, 23, 0)), now),
        DeadlineBucket.today,
      );
      expect(
        service.bucketOf(_task('b', DateTime(2026, 10, 19, 0, 0)), now),
        DeadlineBucket.tomorrow,
      );
      expect(
        service.bucketOf(_task('c', DateTime(2026, 10, 20, 0, 0)), now),
        DeadlineBucket.later,
      );
    });

    test('ラベルは日本語', () {
      expect(service.bucketLabel(DeadlineBucket.today), '本日締切');
      expect(service.bucketLabel(DeadlineBucket.tomorrow), '明日締切');
      expect(service.bucketLabel(DeadlineBucket.later), '以降の締切');
    });
  });

  group('buildBody', () {
    test('対象0件は null（＝通知しない）', () {
      expect(service.buildBody(const [], now), isNull);
    });

    test('当日内の複数件を1行にまとめる', () {
      final tasks = [
        _task('a', DateTime(2026, 10, 18, 10, 0), title: '薬草集め'),
        _task('b', DateTime(2026, 10, 18, 18, 0), title: '洞窟探索'),
      ];
      final selected = service.selectUpcoming(tasks, now, withinDays: 3);
      expect(
        service.buildBody(selected, now),
        '本日締切: 薬草集め、洞窟探索',
      );
    });

    test('区分ごとに行を分け、上限超過は「ほかN件」＋合計行で示す', () {
      final tasks = [
        _task('a', DateTime(2026, 10, 18, 10, 0), title: 'A'),
        _task('b', DateTime(2026, 10, 18, 11, 0), title: 'B'),
        _task('c', DateTime(2026, 10, 19, 10, 0), title: 'C'),
        _task('d', DateTime(2026, 10, 20, 10, 0), title: 'D'),
        _task('e', DateTime(2026, 10, 20, 11, 0), title: 'E'),
      ];
      final selected = service.selectUpcoming(tasks, now, withinDays: 3);
      final body = service.buildBody(selected, now, maxNames: 3);
      expect(
        body,
        '本日締切: A、B\n'
        '明日締切: C\n'
        '以降の締切: 2件\n'
        '（3日以内の合計5件）',
      );
    });

    test('上限が区分の途中で尽きたら残りは件数のみ', () {
      final tasks = [
        _task('a', DateTime(2026, 10, 18, 10, 0), title: 'A'),
        _task('b', DateTime(2026, 10, 18, 11, 0), title: 'B'),
        _task('c', DateTime(2026, 10, 19, 10, 0), title: 'C'),
      ];
      final selected = service.selectUpcoming(tasks, now, withinDays: 3);
      expect(
        service.buildBody(selected, now, maxNames: 2),
        '本日締切: A、B\n明日締切: 1件\n（3日以内の合計3件）',
      );
    });

    test('maxNames が 0 以下なら ArgumentError', () {
      final tasks = [_task('a', DateTime(2026, 10, 18, 10, 0))];
      final selected = service.selectUpcoming(tasks, now, withinDays: 3);
      expect(
        () => service.buildBody(selected, now, maxNames: 0),
        throwsArgumentError,
      );
    });
  });

  group('タイトル・時刻・次回発火', () {
    test('タイトルに件数を含める', () {
      expect(service.buildTitle(3), '⏳ 締切の刻（3件）');
    });

    test('timeLabel はゼロ埋め', () {
      expect(service.timeLabel(8, 5), '08:05');
      expect(service.timeLabel(21, 30), '21:30');
    });

    test('nextOccurrence: 時刻前なら当日、時刻後なら翌日', () {
      final s = DeadlineReminderSettings(enabled: true, hour: 12, minute: 0);
      expect(
        service.nextOccurrence(s, DateTime(2026, 10, 18, 9, 0)),
        DateTime(2026, 10, 18, 12, 0),
      );
      expect(
        service.nextOccurrence(s, DateTime(2026, 10, 18, 13, 0)),
        DateTime(2026, 10, 19, 12, 0),
      );
    });

    test('nextOccurrence: 無効なら null', () {
      expect(
        service.nextOccurrence(
          DeadlineReminderSettings(enabled: false),
          now,
        ),
        isNull,
      );
    });
  });

  group('previewLabel', () {
    test('対象0件はその旨を返す', () {
      expect(
        service.previewLabel(const [], now),
        contains('ありません'),
      );
    });

    test('対象ありは件数と本文を含む', () {
      final tasks = [
        _task('a', DateTime(2026, 10, 18, 10, 0), title: '薬草集め'),
      ];
      final selected = service.selectUpcoming(tasks, now, withinDays: 3);
      final label = service.previewLabel(selected, now);
      expect(label, contains('対象 1件'));
      expect(label, contains('本日締切: 薬草集め'));
    });
  });
}
