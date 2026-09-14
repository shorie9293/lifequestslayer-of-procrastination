import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/domain/services/practice_log_service.dart';

void main() {
  PracticeLog log(DateTime date, int count, {DateTime? updatedAt}) =>
      PracticeLog(
        date: date,
        count: count,
        updatedAt: updatedAt ?? date,
      );

  group('PracticeLogService.record', () {
    test('空ログに新規の日が追加される', () {
      final next = PracticeLogService.record(
        const [],
        at: DateTime(2026, 9, 15, 8),
      );
      expect(next.length, 1);
      expect(next.first.id, '2026-09-15');
      expect(next.first.count, 1);
      expect(next.first.updatedAt, DateTime(2026, 9, 15, 8));
    });

    test('同日の記録は回数を加算し、新しい updatedAt になる', () {
      final next = PracticeLogService.record(
        [log(DateTime(2026, 9, 15), 2, updatedAt: DateTime(2026, 9, 15, 8))],
        at: DateTime(2026, 9, 15, 20),
      );
      expect(next.length, 1);
      expect(next.first.count, 3);
      expect(next.first.updatedAt, DateTime(2026, 9, 15, 20));
    });

    test('amount を指定して複数件記録できる', () {
      final next = PracticeLogService.record(
        const [],
        at: DateTime(2026, 9, 15),
        amount: 4,
      );
      expect(next.first.count, 4);
    });

    test('amount が1未満なら ArgumentError', () {
      expect(
          () => PracticeLogService.record(const [], at: DateTime.now(), amount: 0),
          throwsArgumentError);
    });

    test('結果は日付昇順に整列される', () {
      final next = PracticeLogService.record(
        [log(DateTime(2026, 9, 20), 1), log(DateTime(2026, 9, 10), 1)],
        at: DateTime(2026, 9, 15),
      );
      expect(next.map((l) => l.id).toList(),
          ['2026-09-10', '2026-09-15', '2026-09-20']);
    });

    test('入力ログ自体は変更されない（純粋）', () {
      final original = [log(DateTime(2026, 9, 15), 1)];
      PracticeLogService.record(original, at: DateTime(2026, 9, 15));
      expect(original.first.count, 1);
    });
  });

  group('PracticeLogService.normalize', () {
    test('同日重複は回数を合算し、updatedAt は新しい方を保つ', () {
      final merged = PracticeLogService.normalize([
        log(DateTime(2026, 9, 15), 1, updatedAt: DateTime(2026, 9, 15, 9)),
        log(DateTime(2026, 9, 15), 2, updatedAt: DateTime(2026, 9, 15, 21)),
      ]);
      expect(merged.length, 1);
      expect(merged.first.count, 3);
      expect(merged.first.updatedAt, DateTime(2026, 9, 15, 21));
    });

    test('時刻違いの同日も同じ日として統合される', () {
      final merged = PracticeLogService.normalize([
        log(DateTime(2026, 9, 15, 1), 1),
        log(DateTime(2026, 9, 15, 23), 1),
      ]);
      expect(merged.length, 1);
      expect(merged.first.count, 2);
    });

    test('空入力は空を返す', () {
      expect(PracticeLogService.normalize(const []), isEmpty);
    });
  });

  group('PracticeLogService 集計', () {
    final logs = [
      log(DateTime(2026, 9, 1), 2),
      log(DateTime(2026, 9, 2), 1),
    ];

    test('countsByDay は日付→回数マップを返す', () {
      final map = PracticeLogService.countsByDay(logs);
      expect(map[DateTime(2026, 9, 1)], 2);
      expect(map[DateTime(2026, 9, 2)], 1);
      expect(map.length, 2);
    });

    test('expand は1完遂=1件の日時リストへ展開する', () {
      final dates = PracticeLogService.expand(logs);
      expect(dates.length, 3);
      expect(dates.where((d) => d == DateTime(2026, 9, 1)).length, 2);
      expect(dates.where((d) => d == DateTime(2026, 9, 2)).length, 1);
    });

    test('totalCount は全回数を合算する', () {
      expect(PracticeLogService.totalCount(logs), 3);
      expect(PracticeLogService.totalCount(const []), 0);
    });
  });

  group('PracticeLogService.mergeActivityDates', () {
    test('ログが無い日は旧来ソースで補完される', () {
      final merged = PracticeLogService.mergeActivityDates(
        logs: [log(DateTime(2026, 9, 1), 1)],
        legacyDates: [DateTime(2026, 9, 2, 10)],
      );
      expect(merged.length, 2);
      expect(merged.contains(DateTime(2026, 9, 1)), isTrue);
      expect(merged.contains(DateTime(2026, 9, 2)), isTrue);
    });

    test('ログがある日はログが正となり旧来ソースを二重計上しない', () {
      final merged = PracticeLogService.mergeActivityDates(
        logs: [log(DateTime(2026, 9, 1), 3)],
        legacyDates: [DateTime(2026, 9, 1, 9), DateTime(2026, 9, 1, 21)],
      );
      expect(merged.length, 3);
      expect(merged.every((d) => d == DateTime(2026, 9, 1)), isTrue);
    });

    test('ログが空なら旧来ソースのみになる（後方互換）', () {
      final merged = PracticeLogService.mergeActivityDates(
        logs: const [],
        legacyDates: [DateTime(2026, 9, 1), DateTime(2026, 9, 1)],
      );
      expect(merged.length, 2);
    });

    test('両方空なら空を返す', () {
      expect(
        PracticeLogService.mergeActivityDates(logs: const [], legacyDates: const []),
        isEmpty,
      );
    });
  });

  group('PracticeLogService.within', () {
    final logs = [
      log(DateTime(2026, 8, 31), 1),
      log(DateTime(2026, 9, 1), 1),
      log(DateTime(2026, 9, 15), 1),
      log(DateTime(2026, 9, 30), 1),
      log(DateTime(2026, 10, 1), 1),
    ];

    test('両端を含む期間で抽出する', () {
      final picked = PracticeLogService.within(
        logs,
        from: DateTime(2026, 9, 1, 23),
        to: DateTime(2026, 9, 30, 1),
      );
      expect(picked.map((l) => l.id).toList(),
          ['2026-09-01', '2026-09-15', '2026-09-30']);
    });

    test('逆転した期間は空を返す', () {
      expect(
        PracticeLogService.within(
          logs,
          from: DateTime(2026, 9, 30),
          to: DateTime(2026, 9, 1),
        ),
        isEmpty,
      );
    });
  });
}
