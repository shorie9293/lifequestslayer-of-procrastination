import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/utils/date_utils.dart';

void main() {
  group('DateUtils', () {
    test('isSameDay - 同じ日付ならtrue', () {
      final d1 = DateTime(2026, 4, 27, 10, 0, 0);
      final d2 = DateTime(2026, 4, 27, 23, 59, 59);
      expect(DateUtils.isSameDay(d1, d2), true);
    });

    test('isSameDay - 異なる日付ならfalse', () {
      final d1 = DateTime(2026, 4, 27);
      final d2 = DateTime(2026, 4, 28);
      expect(DateUtils.isSameDay(d1, d2), false);
    });

    test('isSameDay - 異なる月ならfalse', () {
      final d1 = DateTime(2026, 4, 27);
      final d2 = DateTime(2026, 5, 27);
      expect(DateUtils.isSameDay(d1, d2), false);
    });

    test('isYesterday - 前日の日付ならtrue', () {
      final today = DateTime(2026, 4, 27);
      final yesterday = DateTime(2026, 4, 26);
      // isYesterday(past, now): pastがnowの昨日かを判定
      expect(DateUtils.isYesterday(yesterday, today), true);
    });

    test('isYesterday - 同日ならfalse', () {
      final today = DateTime(2026, 4, 27);
      expect(DateUtils.isYesterday(today, today), false);
    });

    test('isYesterday - 2日前ならfalse', () {
      final today = DateTime(2026, 4, 27);
      final twoDaysAgo = DateTime(2026, 4, 25);
      expect(DateUtils.isYesterday(today, twoDaysAgo), false);
    });

    test('isDifferentWeek - 同じ週ならfalse', () {
      // 2026-04-27 は月曜日
      final d1 = DateTime(2026, 4, 27); // 月
      final d2 = DateTime(2026, 4, 28); // 火（同じ週）
      expect(DateUtils.isDifferentWeek(d1, d2), false);
    });

    test('isDifferentWeek - 異なる週ならtrue', () {
      final d1 = DateTime(2026, 4, 27); // 月
      final d2 = DateTime(2026, 5, 4);  // 次の週の月曜
      expect(DateUtils.isDifferentWeek(d1, d2), true);
    });
  });
}
