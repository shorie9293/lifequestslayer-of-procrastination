import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/time/local_calendar_date.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/reflection_analytics_service.dart';
import 'package:rpg_todo/domain/services/reflection_backup_codec.dart';
import 'package:rpg_todo/domain/services/habit_calendar_service.dart';

/// 親探針（イシコリドメ）: #245 の不変条件を独立に撃つ。
///
/// 子の試練は「正準関数の単体」と「1経路」しか撃たない傾向があるため、
/// 親は『保存/復元層 → 集計層 → 暦』の合成と、
/// ローカル暦でなければ必ず落ちる識別点を撃つ。
Reflection _r(DateTime date) => Reflection(
      id: 'r-${date.microsecondsSinceEpoch}',
      taskId: 't1',
      date: date,
      content: 'x',
      selfDifficulty: 3,
      aiDifficulty: QuestRank.S,
      sentiment: ReflectionAnalyticsService.sentimentKaishin,
    );

void main() {
  group('親探針: 保存形式(UTC瞬間)と日付キー(ローカル暦)の分離', () {
    test('P1 UTC種別の早朝記録が、ローカル暦の当月バケットに入る', () {
      // JST で 2026-11-01 00:05 になる瞬間（UTC 種別で渡す）
      final instant = DateTime.parse('2026-10-31T15:05:00Z');
      final local = instant.toLocal();
      expect(instant.isUtc, isTrue, reason: '前提: UTC種別であること');

      final now = DateTime(local.year, local.month, 15, 12, 0);
      final a = ReflectionAnalyticsService.compute(
        reflections: [_r(instant)],
        now: now,
        months: 3,
      );

      final ym = a.lastMonths
          .firstWhere((b) => b.year == local.year && b.month == local.month);
      expect(ym.count, 1,
          reason: 'ローカル暦の当月(${local.year}/${local.month})に計上されるべき');
    });

    test('P2 年跨ぎ早朝の記録が、ローカル暦の新年に計上される', () {
      // JST で 2027-01-01 00:30 になる瞬間
      final instant = DateTime.parse('2026-12-31T15:30:00Z');
      final local = instant.toLocal();

      final now = DateTime(local.year, local.month, 1, 12, 0);
      final a = ReflectionAnalyticsService.compute(
        reflections: [_r(instant)],
        now: now,
        months: 3,
      );

      expect(a.currentYearTotal, 1, reason: 'ローカル暦の当年に1件');
      expect(a.previousYearTotal, 0, reason: '前年に落ちてはならない');
    });

    test('P3 バックアップ復元はローカル種別に正規化され、年月日が動かない', () {
      final instant = DateTime.parse('2026-10-31T15:05:00Z');
      final local = instant.toLocal();

      final restored = ReflectionBackupCodec.fromMap({
        'id': 'r1',
        'taskId': 't1',
        'date': instant.toIso8601String(),
        'content': 'x',
        'selfDifficulty': 3,
        'aiDifficulty': 0,
        'sentiment': null,
      });

      expect(restored.date.isUtc, isFalse,
          reason: '復元後の DateTime はローカル種別（isUtc==false）であること');
      expect(restored.date.year, local.year);
      expect(restored.date.month, local.month);
      expect(restored.date.day, local.day);
    });

    test('P4 習慣カレンダーは UTC種別の早朝記録をローカル暦の当日に数える', () {
      final instant = DateTime.parse('2026-10-31T15:05:00Z'); // JST 11/1 00:05
      final local = instant.toLocal();
      final today = DateTime(local.year, local.month, local.day, 12, 0);

      final cal = HabitCalendarService.compute(
        activityDates: [instant],
        now: today,
      );

      final day = cal.month.days
          .firstWhere((d) => d.date.year == local.year &&
              d.date.month == local.month &&
              d.date.day == local.day);
      expect(day.activityCount, 1,
          reason: 'ローカル暦の当日に1件。前日に落ちてはならない');
      expect(cal.month.activeDays, 1);
    });

    test('P5 ローカル種別の入力に対しては従来と同一（意味不変・冪等）', () {
      final a = DateTime(2026, 11, 1, 0, 5);
      final b = DateTime(2026, 11, 30, 23, 59);

      expect(normalizeToLocal(a), same(a));
      expect(localDateOnly(a), DateTime(2026, 11, 1));
      expect(localYear(a), 2026);
      expect(localMonth(a), 11);
      expect(localDay(b), 30);
      expect(isSameLocalMonth(a, b), isTrue);
      expect(isSameLocalYear(a, b), isTrue);
      expect(tryLocalDateOnly(null), isNull);
      expect(localDateOnly(localDateOnly(a)), localDateOnly(a));
    });

    test('P6 識別点: 正準関数を経ない UTC 直読みとは結果が異なる（回帰の効き目）', () {
      final instant = DateTime.parse('2026-10-31T15:05:00Z');
      final legacy = DateTime(instant.year, instant.month, instant.day);
      final canonical = localDateOnly(instant);

      // ローカルが UTC の環境では両者一致するため、識別は『正準が常にローカル暦』
      final expected = DateTime(
        instant.toLocal().year,
        instant.toLocal().month,
        instant.toLocal().day,
      );
      expect(canonical, expected);
      if (instant.toLocal().day != instant.day) {
        expect(canonical, isNot(legacy),
            reason: '早朝の瞬間では旧実装(UTC直読み)と必ず食い違う');
      }
    });
  });
}
