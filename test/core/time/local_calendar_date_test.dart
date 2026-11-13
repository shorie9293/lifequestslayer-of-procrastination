import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/time/local_calendar_date.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/reflection_backup_codec.dart';

/// 局所暦正準関数の試練。
///
/// TZ 非依存に書くため、期待値は必ず「ローカル暦で構築した DateTime」または
/// `DateTime.parse(...).toLocal()` から算出する（ハードコードした暦に依存しない）。
void main() {
  group('normalizeToLocal', () {
    test('UTC 種別は同じ瞬間のローカル表現へ変換される', () {
      final utc = DateTime.parse('2026-10-31T15:05:00Z');
      expect(utc.isUtc, isTrue);
      final local = normalizeToLocal(utc);
      expect(local.isUtc, isFalse);
      expect(local.isAtSameMomentAs(utc), isTrue);
      // ローカル暦の年月日は toLocal() と一致する。
      final expected = utc.toLocal();
      expect(local.year, expected.year);
      expect(local.month, expected.month);
      expect(local.day, expected.day);
      expect(local.hour, expected.hour);
      expect(local.minute, expected.minute);
    });

    test('ローカル種別はそのまま（同一性を含め冪等）', () {
      final local = DateTime(2026, 11, 1, 0, 5);
      final once = normalizeToLocal(local);
      expect(once.isUtc, isFalse);
      expect(once, local);
      expect(normalizeToLocal(once), once);
    });

    test('冪等: 2 回適用しても結果が変わらない', () {
      final inputs = <DateTime>[
        DateTime.parse('2026-10-31T15:05:00Z'),
        DateTime.parse('2026-12-31T14:59:00Z'),
        DateTime(2026, 11, 1, 0, 5),
        DateTime(2025, 12, 31, 23, 59),
      ];
      for (final d in inputs) {
        final once = normalizeToLocal(d);
        final twice = normalizeToLocal(once);
        expect(twice, once, reason: '$d');
        expect(twice.isUtc, once.isUtc, reason: '$d');
      }
    });

    test('例外を投げない（極端な値でも安全）', () {
      final extremes = <DateTime>[
        DateTime.utc(1970, 1, 1),
        DateTime.utc(9999, 12, 31, 23, 59, 59),
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(-1),
      ];
      for (final d in extremes) {
        expect(() => normalizeToLocal(d), returnsNormally, reason: '$d');
      }
    });
  });

  group('localDateOnly / localYear / localMonth / localDay', () {
    test('UTC 種別 ...Z の瞬間をローカル暦で解釈した年月日になる', () {
      // JST 11/1 00:05 = UTC 2026-10-31T15:05:00Z（TZ=UTC では 10/31）
      final utc = DateTime.parse('2026-10-31T15:05:00Z');
      final expected = utc.toLocal();

      final dateOnly = localDateOnly(utc);
      expect(dateOnly.isUtc, isFalse);
      expect(dateOnly.year, expected.year);
      expect(dateOnly.month, expected.month);
      expect(dateOnly.day, expected.day);
      expect(dateOnly.hour, 0);
      expect(dateOnly.minute, 0);
      expect(dateOnly.second, 0);
      expect(dateOnly.millisecond, 0);

      expect(localYear(utc), expected.year);
      expect(localMonth(utc), expected.month);
      expect(localDay(utc), expected.day);
    });

    test('localDateOnly は時刻を 0 時へ落とし冪等', () {
      final d = DateTime(2026, 11, 1, 0, 5, 30, 123);
      final once = localDateOnly(d);
      expect(once, DateTime(2026, 11, 1));
      expect(localDateOnly(once), once);
    });

    test('境界3点: 月初 00:05 / 早朝 08:59 / 年末 23:59（ローカル構築）', () {
      final cases = <DateTime>[
        DateTime(2026, 11, 1, 0, 5), // 月初 00:05
        DateTime(2026, 11, 1, 8, 59), // 早朝 08:59
        DateTime(2025, 12, 31, 23, 59), // 年末 23:59
      ];
      for (final local in cases) {
        expect(localYear(local), local.year, reason: '$local');
        expect(localMonth(local), local.month, reason: '$local');
        expect(localDay(local), local.day, reason: '$local');
        expect(
            localDateOnly(local), DateTime(local.year, local.month, local.day),
            reason: '$local');
      }
    });

    test('境界3点: 同じ瞬間を UTC 種別で渡しても同じ年月日', () {
      final locals = <DateTime>[
        DateTime(2026, 11, 1, 0, 5),
        DateTime(2026, 11, 1, 8, 59),
        DateTime(2025, 12, 31, 23, 59),
      ];
      for (final local in locals) {
        final utc = local.toUtc();
        expect(utc.isUtc, isTrue, reason: '$local');
        expect(localYear(utc), local.year, reason: '$local');
        expect(localMonth(utc), local.month, reason: '$local');
        expect(localDay(utc), local.day, reason: '$local');
        expect(localDateOnly(utc), DateTime(local.year, local.month, local.day),
            reason: '$local');
      }
    });

    test('月境界を跨ぐ瞬間（前月末 UTC）でもローカル暦の月になる', () {
      // JST 12/1 08:59 = UTC 11/30T23:59Z
      final utc = DateTime(2026, 12, 1, 8, 59).toUtc();
      expect(localMonth(utc), 12);
      expect(localDay(utc), 1);
      expect(localYear(utc), 2026);
    });
  });

  group('isSameLocalMonth / isSameLocalYear', () {
    test('ローカル種別同士は従来の年月比較と一致', () {
      expect(isSameLocalMonth(DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
          isTrue);
      expect(isSameLocalMonth(DateTime(2026, 11, 30), DateTime(2026, 12, 1)),
          isFalse);
      expect(isSameLocalYear(DateTime(2026, 1, 1), DateTime(2026, 12, 31)),
          isTrue);
      expect(isSameLocalYear(DateTime(2025, 12, 31), DateTime(2026, 1, 1)),
          isFalse);
    });

    test('UTC 種別の月初早朝でもローカル暦で同月と判定', () {
      final jstEarlyMorning = DateTime(2026, 11, 1, 0, 5).toUtc();
      expect(isSameLocalMonth(jstEarlyMorning, DateTime(2026, 11, 15)), isTrue);
      expect(isSameLocalYear(jstEarlyMorning, DateTime(2026, 11, 15)), isTrue);
      expect(
          isSameLocalMonth(jstEarlyMorning, DateTime(2026, 10, 31)), isFalse);
    });
  });

  group('tryLocalDateOnly', () {
    test('null は null を返す（null 安全）', () {
      expect(tryLocalDateOnly(null), isNull);
    });

    test('非 null は localDateOnly と同じ', () {
      final utc = DateTime.parse('2026-10-31T15:05:00Z');
      expect(tryLocalDateOnly(utc), localDateOnly(utc));
      expect(tryLocalDateOnly(DateTime(2026, 11, 1, 12, 30)),
          DateTime(2026, 11, 1));
    });
  });

  group('ReflectionBackupCodec 往復', () {
    Reflection refl(DateTime date) => Reflection(
          id: 'r1',
          taskId: 't1',
          date: date,
          content: 'c',
          selfDifficulty: 3,
          aiDifficulty: QuestRank.A,
          sentiment: 'kaishin',
        );

    test('JST 早朝の記録が同じ年月日に戻る', () {
      final original = DateTime(2026, 11, 1, 0, 5); // 月初 00:05
      final restored = ReflectionBackupCodec.fromMap(
          ReflectionBackupCodec.toMap(refl(original)));
      expect(restored.date.isUtc, isFalse);
      expect(restored.date.isAtSameMomentAs(original), isTrue);
      expect(localYear(restored.date), original.year);
      expect(localMonth(restored.date), original.month);
      expect(localDay(restored.date), original.day);
    });

    test('年末 23:59 の記録が同じ年月日に戻る', () {
      final original = DateTime(2025, 12, 31, 23, 59);
      final restored = ReflectionBackupCodec.fromMap(
          ReflectionBackupCodec.toMap(refl(original)));
      expect(restored.date.isUtc, isFalse);
      expect(localYear(restored.date), 2025);
      expect(localMonth(restored.date), 12);
      expect(localDay(restored.date), 31);
    });

    test('UTC 種別（...Z）の date を復元しても isUtc==false のローカル瞬間', () {
      final utcInstant = DateTime.parse('2026-10-31T15:05:00Z');
      final map = ReflectionBackupCodec.toMap(refl(utcInstant));
      expect((map['date'] as String).endsWith('Z'), isTrue);

      final restored = ReflectionBackupCodec.fromMap(map);
      expect(restored.date.isUtc, isFalse);
      expect(restored.date.isAtSameMomentAs(utcInstant), isTrue);
      final expected = utcInstant.toLocal();
      expect(localYear(restored.date), expected.year);
      expect(localMonth(restored.date), expected.month);
      expect(localDay(restored.date), expected.day);
    });

    test('Z 無し（ローカル時刻表記）の解釈は不変', () {
      final restored = ReflectionBackupCodec.fromMap(<String, dynamic>{
        'id': 'r1',
        'taskId': 't1',
        'date': '2026-11-01T00:05:00.000',
        'content': 'c',
        'selfDifficulty': 3,
        'aiDifficulty': 1,
        'sentiment': null,
      });
      expect(restored.date.isUtc, isFalse);
      expect(restored.date, DateTime(2026, 11, 1, 0, 5));
    });
  });
}
