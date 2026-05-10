import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/player_avatar_section.dart';

void main() {
  group('PlayerAvatarSection', () {
    testWidgets('デフォルトプレイヤーのアバターを表示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: Player()),
          ),
        ),
      );

      expect(find.text('Lv.1 浪人'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('称号付きプレイヤーを表示', (tester) async {
      final player = Player(equippedTitle: '勇者');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: player),
          ),
        ),
      );

      expect(find.text('【勇者】'), findsOneWidget);
      expect(find.text('Lv.1 浪人'), findsOneWidget);
    });

    testWidgets('戦士の場合Combo表示', (tester) async {
      final player = Player(currentJob: Job.warrior, comboCount: 5);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: player),
          ),
        ),
      );

      expect(find.text('Combo: 5'), findsOneWidget);
    });

    testWidgets('戦士以外はCombo非表示', (tester) async {
      final player = Player(currentJob: Job.cleric, comboCount: 5);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: player),
          ),
        ),
      );

      expect(find.text('Combo: 5'), findsNothing);
    });

    testWidgets('コイン表示を確認', (tester) async {
      final player = Player(coins: 999);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: player),
          ),
        ),
      );

      expect(find.text('999'), findsOneWidget);
    });
  });
}
