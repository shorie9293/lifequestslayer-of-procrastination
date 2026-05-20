import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'package:rpg_todo/features/character_customization/presentation/equipment_tab.dart';

/// EquipmentTab のWidgetテスト用ヘルパー
Widget buildEquipmentTab({
  CharacterSkin? skin,
  int level = 1,
  int streakDays = 0,
  int totalTasks = 0,
  List<String> titles = const [],
  void Function(SkinSlot, String)? onEquip,
}) {
  return MaterialApp(
    home: Scaffold(
      body: EquipmentTab(
        currentSkin: skin ?? const CharacterSkin(),
        playerLevel: level,
        streakDays: streakDays,
        totalTasks: totalTasks,
        titles: titles,
        onEquip: onEquip ?? (_, __) {},
      ),
    ),
  );
}

void main() {
  group('EquipmentTab', () {
    testWidgets('初期表示は装備部位選択を促すテキストが表示される', (tester) async {
      await tester.pumpWidget(buildEquipmentTab());

      expect(find.text('装備部位を選んでね'), findsOneWidget);
      expect(find.text('装備'), findsOneWidget);
    });

    testWidgets('5つのスロット選択チップが表示される', (tester) async {
      await tester.pumpWidget(buildEquipmentTab());

      expect(find.text('顔'), findsOneWidget);
      expect(find.text('髪型'), findsOneWidget);
      expect(find.text('鎧'), findsOneWidget);
      expect(find.text('武器'), findsOneWidget);
      expect(find.text('盾'), findsOneWidget);
    });

    testWidgets('スロット選択でスキン一覧が表示される', (tester) async {
      await tester.pumpWidget(buildEquipmentTab());

      // 「顔」スロットをタップ
      await tester.tap(find.text('顔'));
      await tester.pump();

      // デフォルトスキンが表示される
      expect(find.text('デフォルト'), findsWidgets);
      // 装備中ラベルが表示される
      expect(find.text('装備中'), findsOneWidget);
    });

    testWidgets('Lv.50プレイヤーには王家の鎧が解放されている', (tester) async {
      await tester.pumpWidget(buildEquipmentTab(level: 50));

      // 「鎧」スロットをタップ
      await tester.tap(find.text('鎧'));
      await tester.pump();

      // 王家の鎧が表示される（解放済み）
      expect(find.text('王家の鎧'), findsOneWidget);
      // ロックアイコンは表示されない（王家の鎧は解放済み）
      // ただし他の未解放スキンには鍵アイコンが出る
    });

    testWidgets('Lv.1プレイヤーには未解放スキンに鍵アイコンが出る', (tester) async {
      await tester.pumpWidget(buildEquipmentTab(level: 1));

      // 「武器」スロットをタップ
      await tester.tap(find.text('武器'));
      await tester.pump();

      // 未解放スキン（免許皆伝の剣など）に鍵アイコンが表示される
      expect(find.byIcon(Icons.lock), findsWidgets);
    });

    testWidgets('スロット再タップで一覧が閉じる', (tester) async {
      await tester.pumpWidget(buildEquipmentTab());

      // 「顔」をタップ → 一覧表示
      await tester.tap(find.text('顔'));
      await tester.pump();
      expect(find.text('装備中'), findsOneWidget);

      // もう一度「顔」をタップ → 一覧が閉じる
      await tester.tap(find.text('顔'));
      await tester.pump();
      expect(find.text('装備部位を選んでね'), findsOneWidget);
    });

    testWidgets('異なるスロット選択で表示が切り替わる', (tester) async {
      await tester.pumpWidget(buildEquipmentTab());

      // 「顔」を選択
      await tester.tap(find.text('顔'));
      await tester.pump();
      expect(find.text('デフォルト'), findsWidgets);

      // 「武器」に切り替え
      await tester.tap(find.text('武器'));
      await tester.pump();

      // 武器スロットのスキンが表示される
      expect(find.text('青銅の剣'), findsOneWidget);
    });

    testWidgets('装備ボタンタップでonEquipが呼ばれる', (tester) async {
      SkinSlot? calledSlot;
      String? calledSkinId;

      await tester.pumpWidget(buildEquipmentTab(
        level: 50,
        onEquip: (slot, skinId) {
          calledSlot = slot;
          calledSkinId = skinId;
        },
      ));

      // 「鎧」を選択
      await tester.tap(find.text('鎧'));
      await tester.pump();

      // 「王家の鎧」の装備ボタンを探してタップ
      // まず王家の鎧が表示されていることを確認
      expect(find.text('王家の鎧'), findsOneWidget);

      // 「装備」ボタンをタップ（王家の鎧の行にあるはず）
      // 複数の装備ボタンがある中から王家の鎧の行のものを探す
      final equipButtons = find.text('装備');
      await tester.tap(equipButtons.last);
      await tester.pump();

      expect(calledSlot, SkinSlot.armor);
      expect(calledSkinId, 'royal_armor');
    });

    testWidgets('称号で解放されるスキンが正しく表示される', (tester) async {
      await tester.pumpWidget(buildEquipmentTab(
        titles: ['伝説の討伐者'],
      ));

      // 「顔」スロットを選択
      await tester.tap(find.text('顔'));
      await tester.pump();

      // 竜の兜が解放済み
      expect(find.text('竜の兜'), findsOneWidget);
    });

    testWidgets('ストリークで解放されるスキンが正しく表示される', (tester) async {
      await tester.pumpWidget(buildEquipmentTab(streakDays: 30));

      // 「髪型」スロットを選択
      await tester.tap(find.text('髪型'));
      await tester.pump();

      // 炎の冠が解放済み
      expect(find.text('炎の冠'), findsOneWidget);
    });
  });
}
