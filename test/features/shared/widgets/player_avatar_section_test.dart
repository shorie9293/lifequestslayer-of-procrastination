import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
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
      final player = Player(currentJob: Job.samurai, comboCount: 5);
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
      final player = Player(currentJob: Job.monk, comboCount: 5);
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

    testWidgets('キャラクタースキン装備時に絵文字アイコンを表示', (tester) async {
      const skin = CharacterSkin(
        faceId: 'warrior_face',
        hairId: 'spiky',
        armorId: 'leather_armor',
        weaponId: 'bronze_sword',
        shieldId: 'wooden_shield',
      );
      final player = Player(characterSkin: skin);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: player),
          ),
        ),
      );

      // 各スキンのアイコン絵文字が表示されていることを確認
      expect(find.text('😤'), findsOneWidget); // warrior_face
      expect(find.text('⚡'), findsOneWidget); // spiky
      expect(find.text('🧥'), findsOneWidget); // leather_armor
      expect(find.text('🗡️'), findsOneWidget); // bronze_sword
      expect(find.text('🪵'), findsOneWidget); // wooden_shield
    });

    testWidgets('一部のみ装備時は装備済み部位のみ表示', (tester) async {
      const skin = CharacterSkin(
        faceId: 'sage_face',
        weaponId: 'longsword',
      );
      final player = Player(characterSkin: skin);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: player),
          ),
        ),
      );

      // 装備済み部位のみ表示
      expect(find.text('🧘'), findsOneWidget); // sage_face
      expect(find.text('⚔️'), findsOneWidget); // longsword
      // デフォルト部位は表示されない
      expect(find.text('😶'), findsNothing); // default face
      expect(find.text('💇'), findsNothing); // default hair
    });

    testWidgets('全部位defaultの場合は旧スキン画像にフォールバック', (tester) async {
      final player = Player(equippedSkin: 'skin_1');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerAvatarSection(player: player),
          ),
        ),
      );

      // 旧スキン画像が使われることを確認（Image.assetが存在する）
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
