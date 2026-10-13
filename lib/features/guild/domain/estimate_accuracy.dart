import 'package:flutter/foundation.dart';

import 'task_time_record.dart';

/// 見積もりと実績のずれ方（改善提案 #131）。
enum EstimateAccuracyLevel {
  /// 実績が見積もりを超えた（見積もりが過小）。
  overRun,

  /// 誤差が ±20% 以内。
  onTarget,

  /// 実績が見積もりより短かった（見積もりが過大）。
  underRun,
}

/// [EstimateAccuracyLevel] の表示用拡張。
extension EstimateAccuracyLevelX on EstimateAccuracyLevel {
  /// 日本語ラベル。
  String get label {
    switch (this) {
      case EstimateAccuracyLevel.overRun:
        return '超過';
      case EstimateAccuracyLevel.onTarget:
        return '的中';
      case EstimateAccuracyLevel.underRun:
        return '余裕';
    }
  }

  /// 表示用絵文字。
  String get emoji {
    switch (this) {
      case EstimateAccuracyLevel.overRun:
        return '🔥';
      case EstimateAccuracyLevel.onTarget:
        return '🎯';
      case EstimateAccuracyLevel.underRun:
        return '🍃';
    }
  }
}

/// 見積もり精度の集計結果（不変・値オブジェクト）。
@immutable
class EstimateAccuracyStats {
  /// 集計対象の記録件数。
  final int totalRecords;

  /// 的中（±20% 以内）の件数。
  final int onTargetCount;

  /// 的中率（0..1）。0件のときは 0。
  final double onTargetRate;

  /// 見積もり時間の平均（分）。
  final double averageEstimatedMinutes;

  /// 実績時間の平均（分）。
  final double averageActualMinutes;

  /// 符号付き平均誤差 (actual-est)/est の平均。
  final double averageErrorRate;

  /// 見積もりが最も過大だった記録（actual/est 比が最小）。
  final TaskTimeRecord? mostOverestimated;

  /// 見積もりが最も過小だった記録（actual/est 比が最大）。
  final TaskTimeRecord? mostUnderestimated;

  const EstimateAccuracyStats({
    required this.totalRecords,
    required this.onTargetCount,
    required this.onTargetRate,
    required this.averageEstimatedMinutes,
    required this.averageActualMinutes,
    required this.averageErrorRate,
    required this.mostOverestimated,
    required this.mostUnderestimated,
  });

  /// 記録が0件のとき true。
  bool get isEmpty => totalRecords == 0;

  /// 的中率ラベル（例: '67%'。四捨五入の整数%）。
  String get onTargetRateLabel => '${(onTargetRate * 100).round()}%';

  /// 平均誤差ラベル（例: '+25%' / '-10%' / '±0%'）。
  String get averageErrorRateLabel {
    final percent = (averageErrorRate * 100).round();
    if (percent == 0) return '±0%';
    return percent > 0 ? '+$percent%' : '$percent%';
  }

  /// 平均時間ラベル（例: '見積 30.0分 / 実績 42.0分'）。
  /// 小数は常に第1位まで表示する（試練で形式を固定）。
  String get averageTimeLabel =>
      '見積 ${averageEstimatedMinutes.toStringAsFixed(1)}分'
      ' / 実績 ${averageActualMinutes.toStringAsFixed(1)}分';
}

/// 見積もり精度の集計サービス（純粋・static のみ・副作用なし）。
class EstimateAccuracyService {
  const EstimateAccuracyService._();

  /// 的中とみなす誤差の許容幅（±20%）。
  static const double onTargetTolerance = 0.2;

  /// 符号付き誤差 (actual-est)/est。
  static double errorRateOf(TaskTimeRecord r) =>
      (r.actualMinutes - r.estimatedMinutes) / r.estimatedMinutes;

  /// 実績/見積もりの比 actual/est。
  static double ratioOf(TaskTimeRecord r) =>
      r.actualMinutes / r.estimatedMinutes;

  /// 誤差から判定する。ちょうど ±[onTargetTolerance] は的中。
  static EstimateAccuracyLevel levelOf(TaskTimeRecord r) {
    final rate = errorRateOf(r);
    if (rate > onTargetTolerance) return EstimateAccuracyLevel.overRun;
    if (rate < -onTargetTolerance) return EstimateAccuracyLevel.underRun;
    return EstimateAccuracyLevel.onTarget;
  }

  /// 記録群から集計を作る。空リストでも落ちない（0件・null相当の統計）。
  static EstimateAccuracyStats buildStats(List<TaskTimeRecord> records) {
    if (records.isEmpty) {
      return const EstimateAccuracyStats(
        totalRecords: 0,
        onTargetCount: 0,
        onTargetRate: 0,
        averageEstimatedMinutes: 0,
        averageActualMinutes: 0,
        averageErrorRate: 0,
        mostOverestimated: null,
        mostUnderestimated: null,
      );
    }
    var onTarget = 0;
    var estSum = 0;
    var actSum = 0;
    var errorSum = 0.0;
    TaskTimeRecord? mostOver;
    TaskTimeRecord? mostUnder;
    for (final r in records) {
      if (levelOf(r) == EstimateAccuracyLevel.onTarget) onTarget++;
      estSum += r.estimatedMinutes;
      actSum += r.actualMinutes;
      errorSum += errorRateOf(r);
      if (mostOver == null || ratioOf(r) < ratioOf(mostOver)) {
        mostOver = r;
      }
      if (mostUnder == null || ratioOf(r) > ratioOf(mostUnder)) {
        mostUnder = r;
      }
    }
    final n = records.length;
    return EstimateAccuracyStats(
      totalRecords: n,
      onTargetCount: onTarget,
      onTargetRate: onTarget / n,
      averageEstimatedMinutes: estSum / n,
      averageActualMinutes: actSum / n,
      averageErrorRate: errorSum / n,
      mostOverestimated: mostOver,
      mostUnderestimated: mostUnder,
    );
  }

  /// 記録日時の新しい順に並べる（非破壊）。同時刻は taskId 昇順。
  static List<TaskTimeRecord> sortByRecordedAtDesc(
    List<TaskTimeRecord> records,
  ) {
    final list = records.toList()
      ..sort((a, b) {
        final byTime = b.recordedAt.compareTo(a.recordedAt);
        if (byTime != 0) return byTime;
        return a.taskId.compareTo(b.taskId);
      });
    return list;
  }

  /// レポート見出し用の1行サマリ。0件なら '記録がありません'。
  static String summaryLabel(EstimateAccuracyStats stats) {
    if (stats.isEmpty) return '記録がありません';
    return '的中率 ${stats.onTargetRateLabel}／平均誤差 '
        '${stats.averageErrorRateLabel}（${stats.totalRecords}件）';
  }
}
