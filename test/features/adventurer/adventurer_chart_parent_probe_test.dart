import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart_service.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventurer_chart_screen.dart';

/// 親探針（合成の不変条件）: 眷属の試練は個別要素を撃つが、
/// 「称号の閾値と進捗の整合」「ランクカードが total_tasks を源にすること」は
/// 誰も撃たないため、親が独自に撃って健全性を確証する。
void main() {
  group('親探針: 称号閾値と進捗の整合', () {
    test('閾値の直後で称号が切り替わり、進捗が 0.0 に戻る', () {
      const boundaries = [0, 1, 9, 10, 29, 30, 99, 100];
      const expectedLabels = {
        0: '駆け出し',
        1: '見習い冒険者',
        9: '見習い冒険者',
        10: '一人前冒険者',
        29: '一人前冒険者',
        30: '熟練冒険者',
        99: '熟練冒険者',
        100: '伝説の冒険者',
      };
      for (final x in boundaries) {
        expect(AdventurerChartService.rankLabelFor(x), expectedLabels[x],
            reason: 'x=$x');
      }
      // 各閾値の開始点では進捗 0.0（=そのランクに入ったばかり）
      expect(AdventurerChartService.progressToNextRank(0), 0.0);
      expect(AdventurerChartService.progressToNextRank(10), 0.0);
      expect(AdventurerChartService.progressToNextRank(30), 0.0);
      // 最終ランクは 1.0
      expect(AdventurerChartService.progressToNextRank(100), 1.0);
      expect(AdventurerChartService.progressToNextRank(9999), 1.0);
    });

    test('進捗は単調非減少で 0..1 に収まる', () {
      double prev = 0.0;
      for (var x = 0; x <= 120; x++) {
        final p = AdventurerChartService.progressToNextRank(x);
        expect(p, greaterThanOrEqualTo(0.0));
        expect(p, lessThanOrEqualTo(1.0));
        // ランク跨ぎ以外は単調増加（跨ぎで 0 に戻る）
        if (AdventurerChartService.nextRankThreshold(x) ==
            AdventurerChartService.nextRankThreshold(x - 1 == -1 ? 0 : x - 1)) {
          expect(p, greaterThanOrEqualTo(prev), reason: 'x=$x');
        }
        prev = p;
      }
    });

    test('nextRankThreshold と rankLabelFor の境界が一致する', () {
      for (var x = 0; x < 120; x++) {
        final next = AdventurerChartService.nextRankThreshold(x);
        if (x == 0) {
          // ゼロ状態のみ「駆け出し」。1 件目で「見習い冒険者」へ上がる（設計上の例外）。
          expect(AdventurerChartService.rankLabelFor(0), '駆け出し');
          expect(AdventurerChartService.rankLabelFor(1), '見習い冒険者');
        } else if (next == null) {
          expect(AdventurerChartService.rankLabelFor(x), '伝説の冒険者');
        } else {
          // 次の閾値の直前までは称号が変わらない
          expect(AdventurerChartService.rankLabelFor(x),
              AdventurerChartService.rankLabelFor(next - 1),
              reason: 'x=$x next=$next');
          // 閾値に到達すると称号が変わる
          expect(AdventurerChartService.rankLabelFor(x),
              isNot(AdventurerChartService.rankLabelFor(next)),
              reason: 'x=$x next=$next');
        }
      }
    });
  });

  group('親探針: ランクカードは total_tasks を源にする（合成）', () {
    testWidgets('Sランク件数が大きくても称号は総クエスト完了数で決まる', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chart = AdventurerChartService.build(Player(
        totalTasksCompleted: 42,
        totalSRankCompleted: 100,
        totalARankCompleted: 100,
        totalBRankCompleted: 100,
      ));
      await tester.pumpWidget(MaterialApp(home: AdventurerChartScreen(chart: chart)));
      await tester.pumpAndSettle();

      // 総計 342 ではなく 42 を源にすること
      expect(find.text('熟練冒険者'), findsOneWidget);
      expect(find.text('次の称号まで 100件'), findsOneWidget);
    });

    testWidgets('進捗バーの値が progressToNextRank と一致する', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 総完了 20 件 → 次は 30、直前閾値 10 → (20-10)/(30-10) = 0.5
      final chart = AdventurerChartService.build(Player(totalTasksCompleted: 20));
      await tester.pumpWidget(MaterialApp(home: AdventurerChartScreen(chart: chart)));
      await tester.pumpAndSettle();

      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(0.5, 1e-9));
      expect(AdventurerChartService.progressToNextRank(20), closeTo(0.5, 1e-9));
    });

    testWidgets('最終ランクは最高到達点・バー満タン', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final chart = AdventurerChartService.build(Player(totalTasksCompleted: 100));
      await tester.pumpWidget(MaterialApp(home: AdventurerChartScreen(chart: chart)));
      await tester.pumpAndSettle();

      expect(find.text('伝説の冒険者'), findsOneWidget);
      expect(find.text('最高到達点'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 1.0);
    });
  });

  group('親探針: ゼロ状態でも落ちない', () {
    test('全ゼロ player でも build は4グループを返し、空ではない', () {
      final chart = AdventurerChartService.build(Player());
      expect(chart.groups.length, 4);
      expect(chart.isEmpty, isFalse); // エントリ自体は存在する（値0）
      expect(chart.allEntries.length, 8);
      expect(chart.rankLabel, '駆け出し');
      expect(chart.entryById('unknown_id'), isNull);
      expect(chart.groupById('unknown'), isNull);
    });

    testWidgets('ゼロ状態の画面も描画できる', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
          MaterialApp(home: AdventurerChartScreen(player: Player())));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.adventurerRankCard), findsOneWidget);
      expect(find.text('駆け出し'), findsOneWidget);
    });
  });
}
