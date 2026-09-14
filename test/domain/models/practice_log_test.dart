import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';

void main() {
  group('PracticeLog', () {
    test('日付は時刻を捨てて年月日に正規化される', () {
      final log = PracticeLog(
        date: DateTime(2026, 9, 15, 23, 59, 59),
        count: 3,
        updatedAt: DateTime(2026, 9, 15, 23, 59, 59),
      );
      expect(log.date, DateTime(2026, 9, 15));
      expect(log.count, 3);
    });

    test('count が1未満なら ArgumentError', () {
      expect(() => PracticeLog(date: DateTime(2026, 9, 15), count: 0),
          throwsArgumentError);
      expect(() => PracticeLog(date: DateTime(2026, 9, 15), count: -1),
          throwsArgumentError);
    });

    test('id は yyyy-MM-dd 形式（ゼロ埋め）', () {
      expect(PracticeLog(date: DateTime(2026, 9, 5)).id, '2026-09-05');
      expect(PracticeLog(date: DateTime(2026, 12, 31)).id, '2026-12-31');
      expect(PracticeLog.keyOf(DateTime(2027, 1, 1, 8)), '2027-01-01');
    });

    test('normalizeDate は時刻を落とす', () {
      expect(PracticeLog.normalizeDate(DateTime(2026, 9, 15, 3, 4, 5)),
          DateTime(2026, 9, 15));
    });

    test('toJson / fromJson が往復する', () {
      final log = PracticeLog(
        date: DateTime(2026, 9, 15),
        count: 2,
        updatedAt: DateTime(2026, 9, 15, 20, 30),
      );
      final restored = PracticeLog.fromJson(log.toJson());
      expect(restored, log);
      expect(restored.date, DateTime(2026, 9, 15));
      expect(restored.count, 2);
      expect(restored.updatedAt, DateTime(2026, 9, 15, 20, 30));
    });

    test('fromJson は破損（キー欠落・型不一致・count<1）を FormatException にする', () {
      expect(() => PracticeLog.fromJson({'count': 1}),
          throwsFormatException);
      expect(
          () => PracticeLog.fromJson(
              {'date': '2026-09-15', 'count': 1, 'updatedAt': 5}),
          throwsFormatException);
      expect(
          () => PracticeLog.fromJson(
              {'date': 'not-a-date', 'count': 1, 'updatedAt': '2026-09-15'}),
          throwsFormatException);
      expect(
          () => PracticeLog.fromJson(
              {'date': '2026-09-15', 'count': 0, 'updatedAt': '2026-09-15'}),
          throwsFormatException);
    });

    test('copyWith は指定した項目だけを差し替える', () {
      final log = PracticeLog(
        date: DateTime(2026, 9, 15),
        count: 1,
        updatedAt: DateTime(2026, 9, 15, 10),
      );
      final next = log.copyWith(count: 5);
      expect(next.count, 5);
      expect(next.date, log.date);
      expect(next.updatedAt, log.updatedAt);
    });

    test('値等価（date/count/updatedAt が一致すれば等しい）', () {
      final a = PracticeLog(
        date: DateTime(2026, 9, 15),
        count: 2,
        updatedAt: DateTime(2026, 9, 15, 10),
      );
      final b = PracticeLog(
        date: DateTime(2026, 9, 15),
        count: 2,
        updatedAt: DateTime(2026, 9, 15, 10),
      );
      final c = a.copyWith(count: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
