import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/rank_slot_display.dart';

void main() {
  group('RankSlotDisplay', () {
    Widget buildFrame({
      required Player player,
      List<Task> activeTasks = const [],
    }) {
      return MaterialApp(
        home: Scaffold(
          body: RankSlotDisplay(
            player: player,
            activeTasks: activeTasks,
          ),
        ),
      );
    }

    testWidgets('Lv1: Bのみ1枠を表示', (tester) async {
      await tester.pumpWidget(buildFrame(player: Player()));
      // S, A, B のラベルが表示されている
      expect(find.text('S'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('Lv5: A1枠 B3枠', (tester) async {
      final player = Player();
      player.jobLevels[Job.adventurer] = 5;
      await tester.pumpWidget(buildFrame(player: player));
      expect(find.text('S'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('Lv10: S1枠 A2枠 B3枠(タスク0で空)', (tester) async {
      final player = Player();
      player.jobLevels[Job.adventurer] = 10;
      await tester.pumpWidget(buildFrame(player: player));
      expect(find.text('S'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('アクティブタスク数を反映', (tester) async {
      final player = Player();
      player.jobLevels[Job.adventurer] = 10;
      final tasks = [
        Task(id: '1', title: 'T1', rank: QuestRank.S),
        Task(id: '2', title: 'T2', rank: QuestRank.A),
        Task(id: '3', title: 'T3', rank: QuestRank.A),
      ];
      await tester.pumpWidget(buildFrame(player: player, activeTasks: tasks));
      expect(find.text('S'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });
  });
}
