import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart_service.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventurer_chart_screen.dart';

void main() {
  testWidgets('カルテ画面: ランクカード・グループ・エントリ行が表示される', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final chart = AdventurerChartService.build(Player(
      jobLevels: const {Job.adventurer: 3},
      totalTasksCompleted: 42,
      totalSRankCompleted: 5,
    ));

    await tester.pumpWidget(
      MaterialApp(home: AdventurerChartScreen(chart: chart)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.adventurerChartScreen), findsOneWidget);
    expect(find.byKey(AppKeys.adventurerRankCard), findsOneWidget);
    expect(find.byKey(AppKeys.adventurerGroupSection('quests')), findsOneWidget);
    expect(find.byKey(AppKeys.adventurerStatRow('total_tasks')), findsOneWidget);

    expect(find.text('42件'), findsOneWidget);
    expect(find.text('熟練冒険者'), findsOneWidget);
  });

  testWidgets('player注入でProviderなしでも動く', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: AdventurerChartScreen(player: Player(totalTasksCompleted: 10)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.adventurerChartScreen), findsOneWidget);
    expect(find.text('一人前冒険者'), findsOneWidget);
  });
}
