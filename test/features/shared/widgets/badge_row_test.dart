import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/badge_row.dart';

void main() {
  group('BadgeRow', () {
    Widget buildFrame({
      int streakDays = 0,
      int dailyMissionProgress = 0,
      bool isDailyMissionComplete = false,
      int weeklyMissionProgress = 0,
      bool isWeeklyMissionComplete = false,
      int dailyMissionGoal = 3,
      int weeklyMissionGoal = 1,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: BadgeRow(
            streakDays: streakDays,
            dailyMissionProgress: dailyMissionProgress,
            isDailyMissionComplete: isDailyMissionComplete,
            weeklyMissionProgress: weeklyMissionProgress,
            isWeeklyMissionComplete: isWeeklyMissionComplete,
            dailyMissionGoal: dailyMissionGoal,
            weeklyMissionGoal: weeklyMissionGoal,
          ),
        ),
      );
    }

    testWidgets('ストリーク0日を表示', (tester) async {
      await tester.pumpWidget(buildFrame(streakDays: 0));

      expect(find.textContaining('0 日連続'), findsOneWidget);
    });

    testWidgets('ストリーク7日以上でホット表示', (tester) async {
      await tester.pumpWidget(buildFrame(streakDays: 7));

      expect(find.textContaining('7 日連続'), findsOneWidget);
    });

    testWidgets('デイリーミッション未達成を表示', (tester) async {
      await tester.pumpWidget(buildFrame(
        dailyMissionProgress: 1,
        isDailyMissionComplete: false,
      ));

      expect(find.textContaining('デイリー: あと2クエスト'), findsOneWidget);
    });

    testWidgets('デイリーミッション達成を表示', (tester) async {
      await tester.pumpWidget(buildFrame(
        dailyMissionProgress: 3,
        isDailyMissionComplete: true,
      ));

      expect(find.textContaining('デイリー達成！'), findsOneWidget);
    });

    testWidgets('週次ミッション未達成を表示', (tester) async {
      await tester.pumpWidget(buildFrame(
        weeklyMissionProgress: 0,
        isWeeklyMissionComplete: false,
      ));

      expect(find.textContaining('週次Sランク: 0/1'), findsOneWidget);
    });

    testWidgets('週次ミッション達成を表示', (tester) async {
      await tester.pumpWidget(buildFrame(
        weeklyMissionProgress: 1,
        isWeeklyMissionComplete: true,
      ));

      expect(find.textContaining('週次ミッション達成！'), findsOneWidget);
    });

    testWidgets('全てのバッジが表示される', (tester) async {
      await tester.pumpWidget(buildFrame(
        streakDays: 3,
        dailyMissionProgress: 2,
        weeklyMissionProgress: 0,
      ));

      expect(find.textContaining('3 日連続'), findsOneWidget);
      expect(find.textContaining('デイリー: あと'), findsOneWidget);
      expect(find.textContaining('週次Sランク'), findsOneWidget);
    });
  });
}
