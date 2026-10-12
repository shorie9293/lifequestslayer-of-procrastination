import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/presentation/adventurer_chart_screen.dart';

void main() {
  testWidgets('カルテ AppBar の共有ボタンから戦績カード画面へ遷移する', (tester) async {
    final player = Player(
      jobLevels: {Job.adventurer: 3},
      totalTasksCompleted: 42,
      totalSRankCompleted: 5,
      timesWardenDefeated: 7,
      streakDays: 4,
      longestStreak: 12,
      totalReflections: 20,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdventurerChartScreen(player: player),
      ),
    );

    // player 注入時は Provider に依存しない（context.read は押下時のみ）
    await tester.tap(find.byKey(AppKeys.adventureChartShareEntry));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.adventureShareCardScreen), findsOneWidget);
    expect(find.text('戦績カードを共有'), findsOneWidget);
    // カード内容が描画されていること
    expect(find.text('熟練冒険者'), findsOneWidget);
  });
}
