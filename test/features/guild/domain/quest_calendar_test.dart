// 寄合所カレンダー（純粋関数）の試練。
//
// 日付計算は画面の外（domain）に閉じてあるので、月初・月末・閏年・週の開始を
// ここで機械的に撃てる。画面側は「描くだけ」なので、この層が正なら暦は正しい。

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_calendar.dart';

Task task(
  String id, {
  String? title,
  DateTime? deadline,
  QuestRank rank = QuestRank.B,
}) =>
    Task(
      id: id,
      title: title ?? id,
      deadline: deadline,
      rank: rank,
    );

QuestCalendarCell cellAt(QuestCalendarMonth calendar, DateTime date) =>
    calendar.cells.firstWhere(
      (c) => c.date.year == date.year &&
          c.date.month == date.month &&
          c.date.day == date.day,
      orElse: () => throw StateError('$date のマスが無い'),
    );

void main() {
  group('マス目の骨格', () {
    test('常に 42マス（6週×7日）で、週は7マスずつ', () {
      for (final month in [
        DateTime(2026, 11, 1),
        DateTime(2026, 12, 1),
        DateTime(2028, 2, 1),
        DateTime(2026, 5, 1),
      ]) {
        final calendar = buildQuestCalendar(month: month, tasks: const []);
        expect(calendar.cells.length, 42, reason: '${calendar.label}');
        expect(calendar.weeks.length, 6);
        for (final week in calendar.weeks) {
          expect(week.length, 7);
        }
      }
    });

    test('先頭のマスは必ず日曜（週の開始は日曜）', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 11, 15), // 月初以外の日を渡してもよい
        tasks: const [],
      );
      expect(calendar.cells.first.date.weekday, DateTime.sunday);
      // 2026年11月1日は日曜なので、先頭はその日そのもの
      expect(calendar.cells.first.date, DateTime(2026, 11, 1));
    });

    test('月を跨ぐ月は前月・翌月のマスが inMonth=false になる（2026年12月）', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 12, 1),
        tasks: const [],
      );
      // 12月1日は火曜 → 先頭は11月29日（日）
      expect(calendar.cells.first.date, DateTime(2026, 11, 29));
      expect(calendar.cells.first.inMonth, isFalse);
      expect(cellAt(calendar, DateTime(2026, 12, 1)).inMonth, isTrue);
      expect(cellAt(calendar, DateTime(2026, 12, 31)).inMonth, isTrue);
      final inMonthCount = calendar.cells.where((c) => c.inMonth).length;
      expect(inMonthCount, 31);
    });

    test('閏年2月は29マスが inMonth になる（2028年）', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2028, 2, 10),
        tasks: const [],
      );
      expect(calendar.month, DateTime(2028, 2, 1));
      expect(calendar.cells.where((c) => c.inMonth).length, 29);
    });

    test('見出しは「YYYY年M月」', () {
      final calendar = buildQuestCalendar(
          month: DateTime(2026, 11, 20), tasks: const []);
      expect(calendar.label, '2026年11月');
    });
  });

  group('クエストの配置', () {
    test('期限の日付でマスに入り、時刻は無視される', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 11, 1),
        tasks: [
          task('a', deadline: DateTime(2026, 11, 5, 23, 45)),
          task('b', deadline: DateTime(2026, 11, 5, 1, 5)),
        ],
      );
      final cell = cellAt(calendar, DateTime(2026, 11, 5));
      expect(cell.count, 2);
      expect(cell.id, '2026-11-05');
    });

    test('期限の無いクエストは マスに入らず undated へ分かれる', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 11, 1),
        tasks: [
          task('dated', deadline: DateTime(2026, 11, 3)),
          task('undated1'),
          task('undated2'),
        ],
      );
      expect(cellAt(calendar, DateTime(2026, 11, 3)).count, 1);
      expect(calendar.undated.map((t) => t.id), ['undated1', 'undated2']);
      expect(calendar.inMonthTaskCount, 1);
    });

    test('月外（グリッド上の前月・翌月）の期限もそのマスに入る', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 12, 1),
        tasks: [task('nov', deadline: DateTime(2026, 11, 30))],
      );
      final cell = cellAt(calendar, DateTime(2026, 11, 30));
      expect(cell.inMonth, isFalse);
      expect(cell.count, 1);
      // 表示月の件数には数えない
      expect(calendar.inMonthTaskCount, 0);
    });

    test('同じマスの中は ランク（S→A→B）→ 期限時刻 → 題名 の順', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 11, 1),
        tasks: [
          task('b1', title: 'Bあ', deadline: DateTime(2026, 11, 9)),
          task('s1',
              title: 'Sい',
              deadline: DateTime(2026, 11, 9, 18),
              rank: QuestRank.S),
          task('a1', title: 'Aう', deadline: DateTime(2026, 11, 9), rank: QuestRank.A),
          task('s2', title: 'Sえ', deadline: DateTime(2026, 11, 9, 9), rank: QuestRank.S),
        ],
      );
      final ids = cellAt(calendar, DateTime(2026, 11, 9)).tasks.map((t) => t.id);
      expect(ids, ['s2', 's1', 'a1', 'b1']);
    });

    test('ランク内訳は 0件のランクを出さない', () {
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 11, 1),
        tasks: [
          task('s', deadline: DateTime(2026, 11, 7), rank: QuestRank.S),
          task('b1', deadline: DateTime(2026, 11, 7)),
          task('b2', deadline: DateTime(2026, 11, 7)),
        ],
      );
      expect(cellAt(calendar, DateTime(2026, 11, 7)).rankBreakdown, 'S1・B2');
    });

    test('期限が同じ日時なら題名で安定して並ぶ（順序が揺れない）', () {
      // 題名の比較はコードポイント順（'あ' U+3042 < 'さ' U+3055）。
      // 直観の「五十音順」ではなく機械順であることを固定する。
      final calendar = buildQuestCalendar(
        month: DateTime(2026, 11, 1),
        tasks: [
          task('z', title: 'あとの', deadline: DateTime(2026, 11, 2)),
          task('y', title: 'さきの', deadline: DateTime(2026, 11, 2)),
        ],
      );
      final titles =
          cellAt(calendar, DateTime(2026, 11, 2)).tasks.map((t) => t.title);
      expect(titles, ['あとの', 'さきの']);
    });
  });

  group('月送り', () {
    test('12月の翌月は翌年1月', () {
      expect(addMonths(DateTime(2026, 12, 1), 1), DateTime(2027, 1, 1));
    });

    test('1月の前月は前年12月', () {
      expect(addMonths(DateTime(2027, 1, 1), -1), DateTime(2026, 12, 1));
    });

    test('月末日を渡しても月初へ正規化される（2月31日の暴発を防ぐ）', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    });
  });

  test('dateOnly は時刻を落とす', () {
    expect(dateOnly(DateTime(2026, 11, 5, 23, 59, 59)), DateTime(2026, 11, 5));
  });
}
