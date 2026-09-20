// 敵討伐図鑑画面の試練（改善提案）。
//
// entriesOverride で討伐済1・未討伐1・希少種1(=討伐済) の3体を構成し、
// 完成率表示・フィルタ切替・シルエット表示・詳細ダイアログ・空状態を検証する。
// 画像デコードが失敗しても errorBuilder でフォールバックするため落ちない。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/enemy_catalog.dart';
import 'package:rpg_todo/features/battle/presentation/enemy_catalog_screen.dart';
import 'package:rpg_todo/domain/models/task.dart';

List<EnemyCatalogEntry> _makeEntries() {
  return [
    // 討伐済・通常種
    EnemyCatalogEntry(
      assetPath: 'assets/sprites/monsters/demons/demon_green_black_armor.png',
      rank: QuestRank.S,
      defeatCount: 3,
      firstDefeatedAt: DateTime(2026, 9, 1, 10, 0),
      lastDefeatedAt: DateTime(2026, 9, 10, 12, 30),
    ),
    // 未討伐・通常種
    EnemyCatalogEntry(
      assetPath: 'assets/sprites/monsters/oni/ogre_green.png',
      rank: QuestRank.A,
      defeatCount: 0,
    ),
    // 討伐済・希少種
    EnemyCatalogEntry(
      assetPath: 'assets/sprites/monsters/oni/oni_red_samurai.png',
      rank: QuestRank.A,
      isRare: true,
      rarityLabel: '歴戦の個体',
      defeatCount: 1,
      firstDefeatedAt: DateTime(2026, 9, 5, 8, 0),
      lastDefeatedAt: DateTime(2026, 9, 5, 8, 0),
    ),
  ];
}

Widget _wrap(Widget child) => MaterialApp(home: child);

Future<void> _pumpCatalog(
  WidgetTester tester, {
  List<EnemyCatalogEntry>? entries,
  BattleRecordRepository? repository,
}) async {
  await tester.pumpWidget(
    _wrap(
      EnemyCatalogScreen(
        repository: repository,
        entriesOverride: entries,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('完成率ヘッダに全種数・討伐済・累計討伐・希少種が表示される',
      (tester) async {
    await _pumpCatalog(tester, entries: _makeEntries());

    expect(find.byKey(AppKeys.enemyCatalogScreen), findsOneWidget);
    expect(find.byKey(AppKeys.enemyCatalogCompletion), findsOneWidget);
    // 2 / 3 種 (67%)
    expect(find.textContaining('2 / 3 種'), findsOneWidget);
    expect(find.textContaining('67%'), findsOneWidget);
    // 累計討伐 4体
    expect(find.textContaining('累計討伐: 4体'), findsOneWidget);
    // 希少種 1 / 1 種
    expect(find.textContaining('希少種: 1 / 1 種'), findsOneWidget);
  });

  testWidgets('グリッドに全3体が並び、討伐済は表示名・回数バッジ、未討伐は???表示',
      (tester) async {
    await _pumpCatalog(tester, entries: _makeEntries());

    expect(find.byKey(AppKeys.enemyCatalogGrid), findsOneWidget);
    // 行 Key が付いている
    expect(
      find.byKey(const Key(
          'row_enemy_catalog_assets/sprites/monsters/demons/demon_green_black_armor.png')),
      findsOneWidget,
    );
    // 討伐済の表示名とバッジ
    expect(find.text('Demon Green Black Armor'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
    // 希少種ラベル
    expect(find.text('歴戦の個体'), findsOneWidget);
    // 未討伐はシルエット + ???
    expect(find.text('???'), findsOneWidget);
  });

  testWidgets('未討伐フィルタで未討伐1体のみ表示される', (tester) async {
    await _pumpCatalog(tester, entries: _makeEntries());

    await tester.tap(find.byKey(AppKeys.enemyCatalogFilterUndiscovered));
    await tester.pumpAndSettle();

    expect(find.text('???'), findsOneWidget);
    expect(find.text('Demon Green Black Armor'), findsNothing);
    expect(find.text('Ogre Green'), findsNothing);
  });

  testWidgets('希少種フィルタで希少種1体のみ表示される', (tester) async {
    await _pumpCatalog(tester, entries: _makeEntries());

    await tester.tap(find.byKey(AppKeys.enemyCatalogFilterRare));
    await tester.pumpAndSettle();

    expect(find.text('Oni Red Samurai'), findsOneWidget);
    expect(find.text('???'), findsNothing);
    expect(find.text('Demon Green Black Armor'), findsNothing);
  });

  testWidgets('すべてフィルタに戻すと全3体が再表示される', (tester) async {
    await _pumpCatalog(tester, entries: _makeEntries());

    await tester.tap(find.byKey(AppKeys.enemyCatalogFilterUndiscovered));
    await tester.pumpAndSettle();
    expect(find.text('Demon Green Black Armor'), findsNothing);

    await tester.tap(find.byKey(AppKeys.enemyCatalogFilterAll));
    await tester.pumpAndSettle();
    expect(find.text('Demon Green Black Armor'), findsOneWidget);
    expect(find.text('???'), findsOneWidget);
  });

  testWidgets('討伐済セルをタップすると詳細ダイアログが出る', (tester) async {
    await _pumpCatalog(tester, entries: _makeEntries());

    await tester.tap(find.text('Demon Green Black Armor'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(AppKeys.enemyCatalogDetailDialog), findsOneWidget);
    expect(find.textContaining('討伐回数: 3回'), findsOneWidget);
    expect(find.textContaining('初討伐: 2026/09/01 10:00'), findsOneWidget);
    expect(find.textContaining('最終討伐: 2026/09/10 12:30'), findsOneWidget);
  });

  testWidgets('未討伐セルをタップすると???のダイアログが出る', (tester) async {
    await _pumpCatalog(tester, entries: _makeEntries());

    await tester.tap(find.byKey(const Key(
        'row_enemy_catalog_assets/sprites/monsters/oni/ogre_green.png')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(AppKeys.enemyCatalogDetailDialog), findsOneWidget);
    expect(find.text('???'), findsWidgets);
    expect(find.textContaining('討伐回数: 0回'), findsOneWidget);
    // 未討伐なので日時は出ない
    expect(find.textContaining('初討伐'), findsNothing);
  });

  testWidgets('空状態: entriesOverride が空なら empty Key が表示される',
      (tester) async {
    await _pumpCatalog(tester, entries: const []);

    expect(find.byKey(AppKeys.enemyCatalogEmpty), findsOneWidget);
    expect(find.byKey(AppKeys.enemyCatalogGrid), findsNothing);
  });

  testWidgets('InMemoryBattleRecordRepository を注入した経路で図鑑が構築される',
      (tester) async {
    final repo = InMemoryBattleRecordRepository();
    await repo.add(BattleRecord(
      id: 'battle_1',
      title: 'オニ討伐',
      occurredAt: DateTime(2026, 9, 3, 9, 0),
      isVictory: true,
      comboCount: 0,
      remainingSubTasks: 0,
      enemyAssetPath:
          'assets/sprites/monsters/oni/oni_red_horned.png',
    ));
    await repo.add(BattleRecord(
      id: 'battle_2',
      title: '敗北',
      occurredAt: DateTime(2026, 9, 4, 9, 0),
      isVictory: false,
      comboCount: 0,
      remainingSubTasks: 1,
      enemyAssetPath:
          'assets/sprites/monsters/oni/oni_red_horned.png',
    ));

    await _pumpCatalog(tester, repository: repo);

    // 17体の雛形に対し、勝利1件のみが討伐済
    expect(find.byKey(AppKeys.enemyCatalogCompletion), findsOneWidget);
    expect(find.textContaining('1 / 17 種'), findsOneWidget);
    // グリッドは遅延ビルドなのでスクロールして該当セルまで進む
    await tester.scrollUntilVisible(
      find.byKey(const Key(
          'row_enemy_catalog_assets/sprites/monsters/oni/oni_red_horned.png')),
      200,
    );
    expect(find.text('Oni Red Horned'), findsOneWidget);
  });
}
