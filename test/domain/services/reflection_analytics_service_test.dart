import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/reflection_analytics_service.dart';

void main() {
  // 基準日時（決定論的テスト用）。2026-09-08 12:00
  final now = DateTime(2026, 9, 8, 12, 0);

  Reflection refl({
    required DateTime date,
    String? sentiment = 'kaishin',
    int selfDifficulty = 3,
    QuestRank ai = QuestRank.A,
  }) {
    return Reflection(
      id: 'r_${date.millisecondsSinceEpoch}_$sentiment',
      taskId: 't1',
      date: date,
      content: 'content',
      selfDifficulty: selfDifficulty,
      aiDifficulty: ai,
      sentiment: sentiment,
    );
  }

  group('ReflectionAnalyticsService.compute', () {
    test('空の場合は全指標ゼロ・lastMonthsは12か月分（すべてcount 0）', () {
      final a = ReflectionAnalyticsService.compute(
        reflections: const [],
        now: now,
      );
      expect(a.totalCount, 0);
      expect(a.currentYearTotal, 0);
      expect(a.previousYearTotal, 0);
      expect(a.activeMonths, 0);
      expect(a.currentMonthlyStreak, 0);
      expect(a.sentiment.kaishin, 0);
      expect(a.sentiment.imashime, 0);
      expect(a.sentiment.unspecified, 0);
      expect(a.lastMonths.length, 12);
      expect(a.lastMonths.every((m) => m.count == 0), isTrue);
      // 12か月が古い順（2025-10 → 2026-09）
      expect(a.lastMonths.first.year, 2025);
      expect(a.lastMonths.first.month, 10);
      expect(a.lastMonths.last.year, 2026);
      expect(a.lastMonths.last.month, 9);
    });

    test('月別バケットに正しく集計される（年跨ぎ含む）', () {
      final a = ReflectionAnalyticsService.compute(
        reflections: [
          refl(date: DateTime(2026, 9, 3)),
          refl(date: DateTime(2026, 9, 8)),
          refl(date: DateTime(2026, 8, 20)),
          refl(date: DateTime(2026, 1, 15)),
          refl(date: DateTime(2025, 12, 31, 23, 59)),
          refl(date: DateTime(2025, 12, 1)),
        ],
        now: now,
      );
      expect(a.totalCount, 6);
      // 最古バケット = 2025-10、最新 = 2026-09
      final sep2026 =
          a.lastMonths.lastWhere((m) => m.year == 2026 && m.month == 9);
      final aug2026 =
          a.lastMonths.firstWhere((m) => m.year == 2026 && m.month == 8);
      final jan2026 =
          a.lastMonths.firstWhere((m) => m.year == 2026 && m.month == 1);
      final dec2025 =
          a.lastMonths.firstWhere((m) => m.year == 2025 && m.month == 12);
      expect(sep2026.count, 2);
      expect(aug2026.count, 1);
      expect(jan2026.count, 1);
      expect(dec2025.count, 2);
    });

    test('年間集計（当年 vs 前年）', () {
      final a = ReflectionAnalyticsService.compute(
        reflections: [
          refl(date: DateTime(2026, 9, 1)), // 当年
          refl(date: DateTime(2026, 1, 1)), // 当年
          refl(date: DateTime(2025, 12, 31)), // 前年
          refl(date: DateTime(2025, 6, 15)), // 前年（window外だが年集計に含む）
          refl(date: DateTime(2024, 11, 11)), // それ以前（window外）
        ],
        now: now,
      );
      expect(a.currentYearTotal, 2);
      expect(a.previousYearTotal, 2);
      expect(a.totalCount, 5);
    });

    test('activeMonths（window内で振り返りのある月数）', () {
      final a = ReflectionAnalyticsService.compute(
        reflections: [
          refl(date: DateTime(2026, 9, 5)),
          refl(date: DateTime(2026, 9, 6)),
          refl(date: DateTime(2026, 7, 2)), // 8月は0、7月に1
          refl(date: DateTime(2025, 11, 10)), // window内
        ],
        now: now,
      );
      // active月: 2026-09, 2026-07, 2025-11 = 3
      expect(a.activeMonths, 3);
    });

    test('currentMonthlyStreak（現在月から連続して振り返りのある月数）', () {
      // 最新の活動月=2026-08以降は0 → streakは2026-08で終わる連続run
      final a = ReflectionAnalyticsService.compute(
        reflections: [
          refl(date: DateTime(2026, 8, 20)),
          refl(date: DateTime(2026, 7, 10)),
          refl(date: DateTime(2026, 6, 5)),
          refl(date: DateTime(2026, 4, 1)), // 5月が空 → runは6-8月で途切れ
        ],
        now: now,
      );
      // 最新active月=2026-08 → 8月(1) + 7月(2) + 6月(3)、5月(0)で停止
      expect(a.currentMonthlyStreak, 3);
    });

    test('currentMonthlyStreak（現在月に活動があればそれも含む）', () {
      final a = ReflectionAnalyticsService.compute(
        reflections: [
          refl(date: DateTime(2026, 9, 8)), // 現在月に活動
          refl(date: DateTime(2026, 8, 8)),
          refl(date: DateTime(2026, 7, 8)),
        ],
        now: now,
      );
      expect(a.currentMonthlyStreak, 3);
    });

    test('sentiment内訳（kaishin/imashime/unspecified）を集計する', () {
      final a = ReflectionAnalyticsService.compute(
        reflections: [
          refl(date: DateTime(2026, 9, 1), sentiment: 'kaishin'),
          refl(date: DateTime(2026, 9, 2), sentiment: 'imashime'),
          refl(date: DateTime(2026, 9, 3), sentiment: 'kaishin'),
          refl(date: DateTime(2026, 9, 4), sentiment: null), // 旧データ
        ],
        now: now,
      );
      expect(a.sentiment.kaishin, 2);
      expect(a.sentiment.imashime, 1);
      expect(a.sentiment.unspecified, 1);
      expect(a.sentiment.total, 4);
    });

    test('窓サイズを指定するとその月数ぶんバケットが返る', () {
      final a = ReflectionAnalyticsService.compute(
        reflections: const [],
        now: now,
        months: 6,
      );
      expect(a.lastMonths.length, 6);
      expect(a.lastMonths.first.year, 2026);
      expect(a.lastMonths.first.month, 4);
      expect(a.lastMonths.last.month, 9);
    });
  });
}
