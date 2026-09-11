import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/growth_trajectory.dart';
import 'package:rpg_todo/features/overview/presentation/widgets/growth_trajectory_chart.dart';

void main() {
  GrowthMonthlyPoint point({
    int year = 2026,
    int month = 9,
    int quests = 0,
    int defeats = 0,
    int cumQuests = 0,
    int cumDefeats = 0,
  }) =>
      GrowthMonthlyPoint(
        year: year,
        month: month,
        questsCompleted: quests,
        defeats: defeats,
        cumulativeQuests: cumQuests,
        cumulativeDefeats: cumDefeats,
      );

  GrowthTrajectory emptyTrajectory() => GrowthTrajectory(
        points: [
          point(month: 8, cumQuests: 5, cumDefeats: 2),
          point(month: 9, cumQuests: 5, cumDefeats: 2),
        ],
        totalQuestsCompleted: 5,
        totalDefeats: 2,
        activeMonths: 0,
        longestActiveStreak: 0,
      );

  final richTrajectory = GrowthTrajectory(
    points: [
      point(month: 7, quests: 1, cumQuests: 1, cumDefeats: 0),
      point(month: 8, quests: 2, defeats: 1, cumQuests: 3, cumDefeats: 1),
      point(month: 9, quests: 1, defeats: 2, cumQuests: 4, cumDefeats: 3),
    ],
    totalQuestsCompleted: 4,
    totalDefeats: 3,
    activeMonths: 3,
    longestActiveStreak: 3,
    bestMonth: point(month: 9, quests: 1, defeats: 2, cumQuests: 4, cumDefeats: 3),
  );

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: child),
      );

  group('GrowthTrajectoryChart', () {
    testWidgets('活動ゼロなら空メッセージを表示する', (tester) async {
      await tester.pumpWidget(host(
        GrowthTrajectoryChart(trajectory: emptyTrajectory()),
      ));
      expect(find.byKey(const Key('growth_chart_empty')), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('データがあれば折れ線グラフと凡例を描画する', (tester) async {
      await tester.pumpWidget(host(
        GrowthTrajectoryChart(trajectory: richTrajectory),
      ));
      expect(find.byKey(const Key('growth_chart_canvas')), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('勤行完了'), findsOneWidget);
      expect(find.text('討伐勝利'), findsOneWidget);
    });

    testWidgets('月別モードでもグラフを描画する', (tester) async {
      await tester.pumpWidget(host(
        GrowthTrajectoryChart(trajectory: richTrajectory, showCumulative: false),
      ));
      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  group('GrowthTrajectoryView', () {
    testWidgets('ヘッダに現在レベルと累積統計を表示する', (tester) async {
      await tester.pumpWidget(host(GrowthTrajectoryView(
        trajectory: richTrajectory,
        level: 12,
        exp: 30,
        expToNextLevel: 100,
      )));
      expect(find.text('現在 Lv.12 ／ EXP 30/100'), findsOneWidget);
      expect(find.text('累積 勤行'), findsOneWidget);
      expect(find.text('4'), findsWidgets);
      expect(find.text('3か月'), findsOneWidget);
      expect(find.text('2026/9'), findsOneWidget);
    });

    testWidgets('累積/月別の切替ができる', (tester) async {
      await tester.pumpWidget(host(GrowthTrajectoryView(
        trajectory: richTrajectory,
      )));
      expect(find.byKey(const Key('growth_mode_toggle')), findsOneWidget);
      expect(find.byKey(const Key('growth_chart_canvas')), findsOneWidget);
      await tester.tap(find.text('月別'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('growth_chart_canvas')), findsOneWidget);
    });

    testWidgets('月別の歩みリストを新しい月から表示する', (tester) async {
      await tester.pumpWidget(host(GrowthTrajectoryView(
        trajectory: richTrajectory,
      )));
      expect(find.text('勤行 1 ・ 討伐 2'), findsOneWidget);
      expect(find.text('勤行 1 ・ 討伐 0'), findsOneWidget);
    });
  });
}
