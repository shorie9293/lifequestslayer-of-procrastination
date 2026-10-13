import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/guild/domain/estimate_accuracy.dart';
import 'package:rpg_todo/features/guild/domain/task_time_record.dart';

/// 見積もり精度サービス（改善提案 #131）の試練。
void main() {
  final at = DateTime(2026, 10, 14, 9);

  TaskTimeRecord rec(String id, int est, int act) => TaskTimeRecord(
        taskId: id,
        title: '討伐$id',
        estimatedMinutes: est,
        actualMinutes: act,
        recordedAt: at,
      );

  group('errorRateOf', () {
    test('actual > est で正の誤差', () {
      expect(EstimateAccuracyService.errorRateOf(rec('a', 100, 125)), 0.25);
    });

    test('actual < est で負の誤差', () {
      expect(EstimateAccuracyService.errorRateOf(rec('a', 100, 50)), -0.5);
    });

    test('actual == est で 0', () {
      expect(EstimateAccuracyService.errorRateOf(rec('a', 100, 100)), 0.0);
    });
  });

  group('ratioOf', () {
    test('actual/est を返す', () {
      expect(EstimateAccuracyService.ratioOf(rec('a', 100, 125)), 1.25);
    });
  });

  group('levelOf の境界', () {
    test('ちょうど +0.2 は onTarget', () {
      expect(EstimateAccuracyService.levelOf(rec('a', 100, 120)),
          EstimateAccuracyLevel.onTarget);
    });

    test('ちょうど -0.2 は onTarget', () {
      expect(EstimateAccuracyService.levelOf(rec('a', 100, 80)),
          EstimateAccuracyLevel.onTarget);
    });

    test('+0.2 を超えると overRun', () {
      expect(EstimateAccuracyService.levelOf(rec('a', 100, 121)),
          EstimateAccuracyLevel.overRun);
    });

    test('-0.2 未満は underRun', () {
      expect(EstimateAccuracyService.levelOf(rec('a', 100, 79)),
          EstimateAccuracyLevel.underRun);
    });
  });

  group('EstimateAccuracyLevelX ラベル', () {
    test('超過・的中・余裕のラベル', () {
      expect(EstimateAccuracyLevel.overRun.label, '超過');
      expect(EstimateAccuracyLevel.onTarget.label, '的中');
      expect(EstimateAccuracyLevel.underRun.label, '余裕');
      expect(EstimateAccuracyLevel.overRun.emoji, isNotEmpty);
      expect(EstimateAccuracyLevel.onTarget.emoji, isNotEmpty);
      expect(EstimateAccuracyLevel.underRun.emoji, isNotEmpty);
    });
  });

  group('buildStats 空リスト', () {
    test('0件でも落ちない（isEmpty・0値・null）', () {
      final s = EstimateAccuracyService.buildStats(const []);
      expect(s.isEmpty, isTrue);
      expect(s.totalRecords, 0);
      expect(s.onTargetCount, 0);
      expect(s.onTargetRate, 0.0);
      expect(s.averageEstimatedMinutes, 0.0);
      expect(s.averageActualMinutes, 0.0);
      expect(s.averageErrorRate, 0.0);
      expect(s.mostOverestimated, isNull);
      expect(s.mostUnderestimated, isNull);
    });
  });

  group('buildStats 集計', () {
    // est: 100/100/100, act: 120/90/300
    final records = [
      rec('a', 100, 120), // rate +0.2 → 的中
      rec('b', 100, 90), // rate -0.1 → 的中
      rec('c', 100, 300), // rate +2.0 → 超過
    ];

    test('件数と的中率', () {
      final s = EstimateAccuracyService.buildStats(records);
      expect(s.totalRecords, 3);
      expect(s.onTargetCount, 2);
      expect(s.onTargetRate, closeTo(2 / 3, 1e-9));
      expect(s.isEmpty, isFalse);
    });

    test('平均 est / 平均 act', () {
      final s = EstimateAccuracyService.buildStats(records);
      expect(s.averageEstimatedMinutes, 100.0);
      expect(s.averageActualMinutes, closeTo((120 + 90 + 300) / 3, 1e-9));
    });

    test('平均誤差（符号付き）', () {
      final s = EstimateAccuracyService.buildStats(records);
      final expected = (0.2 + -0.1 + 2.0) / 3;
      expect(s.averageErrorRate, closeTo(expected, 1e-9));
    });

    test('mostOverestimated は actual/est 比が最小（見積もり過大）', () {
      final s = EstimateAccuracyService.buildStats(records);
      expect(s.mostOverestimated?.taskId, 'b'); // 比率 0.9 が最小
    });

    test('mostUnderestimated は actual/est 比が最大（見積もり過小）', () {
      final s = EstimateAccuracyService.buildStats(records);
      expect(s.mostUnderestimated?.taskId, 'c'); // 比率 3.0 が最大
    });

    test('1件のみでは most 両方が同じ記録を指す', () {
      final s = EstimateAccuracyService.buildStats([rec('a', 100, 150)]);
      expect(s.mostOverestimated, s.mostUnderestimated);
    });
  });

  group('ラベル', () {
    test('onTargetRateLabel は四捨五入の整数%', () {
      final s = EstimateAccuracyService.buildStats([
        rec('a', 100, 100),
        rec('b', 100, 100),
        rec('c', 100, 200), // 超過
      ]);
      expect(s.onTargetRateLabel, '67%');
    });

    test('averageErrorRateLabel の符号付き%表示', () {
      expect(
        EstimateAccuracyService
            .buildStats([rec('a', 100, 125)]).averageErrorRateLabel,
        '+25%',
      );
      expect(
        EstimateAccuracyService
            .buildStats([rec('a', 100, 90)]).averageErrorRateLabel,
        '-10%',
      );
      expect(
        EstimateAccuracyService
            .buildStats([rec('a', 100, 100)]).averageErrorRateLabel,
        '±0%',
      );
    });

    test('averageTimeLabel は小数第1位まで固定（仕様固定）', () {
      final s = EstimateAccuracyService.buildStats([
        rec('a', 30, 40),
        rec('b', 30, 44),
      ]);
      // 平均 est 30.0 / 平均 act 42.0
      expect(s.averageTimeLabel, '見積 30.0分 / 実績 42.0分');
    });

    test('averageTimeLabel は小数ありの値も第1位に丸める', () {
      final s = EstimateAccuracyService.buildStats([
        rec('a', 10, 10),
        rec('b', 11, 11),
      ]);
      // 平均 est 10.5
      expect(s.averageTimeLabel, '見積 10.5分 / 実績 10.5分');
    });
  });

  group('sortByRecordedAtDesc', () {
    test('非破壊・新しい順に並ぶ', () {
      final old = TaskTimeRecord(
        taskId: 'a',
        title: 'x',
        estimatedMinutes: 10,
        actualMinutes: 10,
        recordedAt: at,
      );
      final new_ = TaskTimeRecord(
        taskId: 'b',
        title: 'x',
        estimatedMinutes: 10,
        actualMinutes: 10,
        recordedAt: at.add(const Duration(minutes: 1)),
      );
      final input = [old, new_];
      final sorted = EstimateAccuracyService.sortByRecordedAtDesc(input);
      expect(sorted, [new_, old]);
      expect(input, [old, new_]); // 非破壊
    });

    test('同時刻は taskId 昇順', () {
      final b = rec('b', 10, 10);
      final a = rec('a', 10, 10);
      final sorted = EstimateAccuracyService.sortByRecordedAtDesc([b, a]);
      expect(sorted.map((r) => r.taskId).toList(), ['a', 'b']);
    });
  });

  group('summaryLabel', () {
    test('0件なら 記録がありません', () {
      expect(
        EstimateAccuracyService.summaryLabel(
          EstimateAccuracyService.buildStats(const []),
        ),
        '記録がありません',
      );
    });

    test('的中率と平均誤差を含む日本語1行', () {
      final s = EstimateAccuracyService.buildStats([
        rec('a', 100, 110),
        rec('b', 100, 100),
      ]);
      final label = EstimateAccuracyService.summaryLabel(s);
      expect(label.contains('100%'), isTrue);
      expect(label.contains('+5%'), isTrue);
      expect(label.contains('\n'), isFalse);
    });
  });
}
