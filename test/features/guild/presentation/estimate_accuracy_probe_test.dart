import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/guild/domain/estimate_accuracy.dart';
import 'package:rpg_todo/features/guild/domain/task_time_record.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_keys.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_screen.dart';

/// 見積もり精度レポート（改善提案 #131）の親探針。
///
/// 眷属は個別操作を撃ちがちなので、親が「合成の不変条件」と
/// 「State 陳腐化」を独自データで撃って健全性を確証する。
TaskTimeRecord _r(String id, int est, int act, {DateTime? at}) =>
    TaskTimeRecord(
      taskId: id,
      title: 'task $id',
      estimatedMinutes: est,
      actualMinutes: act,
      recordedAt: at ?? DateTime(2026, 10, 14, 9),
    );

Widget _app(List<TaskTimeRecord> records) => MaterialApp(
      home: EstimateAccuracyScreen(recordsOverride: records),
    );

void main() {
  testWidgets('親探針: recordsOverride の差し替えに表示が追随する（State 陳腐化の検出）',
      (tester) async {
    await tester.pumpWidget(_app([_r('a', 30, 60)])); // 超過 → 的中率 0%
    await tester.pump();
    expect(find.text('0%'), findsOneWidget);

    await tester.pumpWidget(_app([_r('b', 30, 30)])); // 的中 → 100%
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('親探針: 画面のサマリーはサービスの集計値と一致する（合成の不変条件）',
      (tester) async {
    final records = [
      _r('c', 60, 90, at: DateTime(2026, 10, 12, 9)), // +50% 超過
      _r('d', 20, 20, at: DateTime(2026, 10, 13, 9)), // 的中
      _r('e', 50, 25, at: DateTime(2026, 10, 14, 9)), // -50% 余裕
    ];
    final stats = EstimateAccuracyService.buildStats(records);
    expect(stats.onTargetCount, 1);

    await tester.pumpWidget(_app(records));
    await tester.pump();

    expect(find.text(stats.onTargetRateLabel), findsOneWidget);
    expect(find.text(stats.averageErrorRateLabel), findsOneWidget);
    expect(find.text(stats.averageTimeLabel), findsOneWidget);
    expect(
        find.text(EstimateAccuracyService.summaryLabel(stats)), findsOneWidget);
    for (final r in records) {
      expect(find.byKey(EstimateAccuracyKeys.recordRow(r.id)), findsOneWidget);
    }
  });

  testWidgets('親探針: 負の対照 — 0件では空状態を出しリストを出さない', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();
    expect(find.byKey(EstimateAccuracyKeys.emptyState), findsOneWidget);
    expect(find.byKey(EstimateAccuracyKeys.list), findsNothing);
    expect(find.text('記録がありません'), findsOneWidget);
  });
}
