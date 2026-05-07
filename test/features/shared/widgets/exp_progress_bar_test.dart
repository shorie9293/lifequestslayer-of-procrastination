import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/exp_progress_bar.dart';

void main() {
  group('ExpProgressBar', () {
    Widget buildFrame(Player player) {
      return MaterialApp(
        home: Scaffold(
          body: ExpProgressBar(player: player),
        ),
      );
    }

    testWidgets('EXPバーと数値を表示', (tester) async {
      final player = Player();
      // Lv1: expToNextLevel = 50
      await tester.pumpWidget(buildFrame(player));

      expect(find.textContaining('0 / 50 EXP'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('EXP進捗を正しく表示', (tester) async {
      final player = Player();
      player.jobExps[Job.adventurer] = 25;
      await tester.pumpWidget(buildFrame(player));

      expect(find.textContaining('25 / 50 EXP'), findsOneWidget);
    });

    testWidgets('高レベルでもEXP表示', (tester) async {
      final player = Player();
      player.jobLevels[Job.adventurer] = 10;
      player.jobExps[Job.adventurer] = 500;
      await tester.pumpWidget(buildFrame(player));

      // Lv10: expToNextLevel = 50 * 1.4^9 ≈ 1034
      expect(find.textContaining('500 /'), findsOneWidget);
      expect(find.textContaining('EXP'), findsOneWidget);
    });
  });
}
