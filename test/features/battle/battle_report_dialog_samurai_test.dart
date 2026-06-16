import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/battle/presentation/widgets/battle_report_dialog.dart';

/// Helper: show BattleReportDialog via showDialog and settle animations.
Future<void> pumpBattleReportDialog(
  WidgetTester tester, {
  Player? player,
  String? taskId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => BattleReportDialog(
                  coinsGained: 100,
                  taskId: taskId,
                  player: player,
                ),
              );
            },
            child: const Text('Show Dialog'),
          );
        },
      ),
    ),
  );

  // Tap the button to trigger the dialog
  await tester.tap(find.text('Show Dialog'));
  // Pump to start the dialog animation, then settle to finish it
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  group('BattleReportDialog 振り返りボタン表示分岐', () {
    testWidgets('侍系 + taskIdあり → hasReflection == true（ボタン表示）', (tester) async {
      await pumpBattleReportDialog(
        tester,
        player: Player(currentJob: Job.samurai),
        taskId: 'task-001',
      );
      expect(find.text('戦後の一息を記す'), findsOneWidget);
    });

    testWidgets('非侍系 + taskIdあり → hasReflection == false（ボタン非表示）', (tester) async {
      await pumpBattleReportDialog(
        tester,
        player: Player(currentJob: Job.monk),
        taskId: 'task-001',
      );
      expect(find.text('戦後の一息を記す'), findsNothing);
    });

    testWidgets('player null + taskIdあり → hasReflection == true（後方互換）', (tester) async {
      await pumpBattleReportDialog(
        tester,
        player: null,
        taskId: 'task-001',
      );
      expect(find.text('戦後の一息を記す'), findsOneWidget);
    });

    testWidgets('taskId null → hasReflection == false（既存挙動維持）', (tester) async {
      await pumpBattleReportDialog(
        tester,
        player: Player(currentJob: Job.samurai),
        taskId: null,
      );
      expect(find.text('戦後の一息を記す'), findsNothing);
    });
  });
}
