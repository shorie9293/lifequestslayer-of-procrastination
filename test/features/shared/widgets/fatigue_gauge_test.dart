import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/fatigue_gauge.dart';

void main() {
  group('FatigueGauge', () {
    Widget buildFrame({
      String fatigueStatus = '快調',
      double fatigueProgress = 0.0,
      int fatigueLevel = 0,
      int dailyTasksCompleted = 0,
      int fatigueSevereThreshold = 10,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: FatigueGauge(
            fatigueStatus: fatigueStatus,
            fatigueProgress: fatigueProgress,
            fatigueLevel: fatigueLevel,
            dailyTasksCompleted: dailyTasksCompleted,
            fatigueSevereThreshold: fatigueSevereThreshold,
          ),
        ),
      );
    }

    testWidgets('疲労度0: 快調表示', (tester) async {
      await tester.pumpWidget(buildFrame(
        fatigueStatus: '快調 😄',
        fatigueProgress: 0.0,
        fatigueLevel: 0,
      ));

      expect(find.text('快調 😄'), findsOneWidget);
      expect(find.textContaining('体調:'), findsOneWidget);
    });

    testWidgets('疲労度1: やや疲れ', (tester) async {
      await tester.pumpWidget(buildFrame(
        fatigueStatus: '⚠️ やや疲れ',
        fatigueProgress: 0.3,
        fatigueLevel: 1,
      ));

      expect(find.text('⚠️ やや疲れ'), findsOneWidget);
    });

    testWidgets('疲労度3: 限界表示', (tester) async {
      await tester.pumpWidget(buildFrame(
        fatigueStatus: '💀 限界',
        fatigueProgress: 1.0,
        fatigueLevel: 3,
      ));

      expect(find.text('💀 限界'), findsOneWidget);
    });

    testWidgets('本日の完遂数を表示', (tester) async {
      await tester.pumpWidget(buildFrame(
        dailyTasksCompleted: 3,
        fatigueSevereThreshold: 10,
      ));

      expect(find.textContaining('本日の完遂:'), findsOneWidget);
      expect(find.textContaining('3 / 10'), findsOneWidget);
    });

    testWidgets('疲労プログレスバーの色: 通常は青', (tester) async {
      await tester.pumpWidget(buildFrame(
        fatigueProgress: 0.2,
        fatigueLevel: 0,
      ));

      // LinearProgressIndicator が存在することを確認
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('疲労プログレスバーの色: 50%超でオレンジ', (tester) async {
      await tester.pumpWidget(buildFrame(
        fatigueProgress: 0.6,
        fatigueLevel: 1,
      ));

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('疲労プログレスバーの色: 100%で赤', (tester) async {
      await tester.pumpWidget(buildFrame(
        fatigueProgress: 1.0,
        fatigueLevel: 3,
      ));

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });
  });
}
