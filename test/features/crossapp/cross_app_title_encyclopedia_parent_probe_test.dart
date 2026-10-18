import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_collection.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';
import 'package:rpg_todo/features/crossapp/presentation/cross_app_title_encyclopedia_screen.dart';

/// 親探針: 画面 → 純粋サービス の合成不変条件を撃つ。
/// 子の試練は個別操作を検証しがちなため、親が意味論から再計算して固定する。
void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<String> ownedTitles,
    List<CrossAppTitleDefinition> definitions = kCrossAppTitles,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CrossAppTitleEncyclopediaScreen(
          ownedTitles: ownedTitles,
          definitions: definitions,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('画面の行が純粋サービス出力と同一（定義順・全11件・独自集計なし）',
      (tester) async {
    final owned = <String>[
      kCrossAppTitles[0].id, // 読書家の卵
      kCrossAppTitles[1].id, // 書庫の冒険者
      '存在しない称号',
      kCrossAppTitles[0].id, // 重複
    ];
    final collection =
        const CrossAppTitleService().build(ownedTitles: owned);

    await pumpScreen(tester, ownedTitles: owned);

    // 全定義の行が存在する
    for (final entry in collection.entries) {
      expect(find.byKey(AppKeys.crossAppTitleRow(entry.id)), findsOneWidget,
          reason: '行が欠落: ${entry.id}');
    }
    expect(collection.total, kCrossAppTitles.length);
    expect(collection.total, 11);
    // 未知称号名は行にならない（既知の11行のみ）
    expect(find.text('存在しない称号'), findsNothing);
    // サマリーはサービス出力と完全一致
    expect(find.text(collection.summaryLabel), findsOneWidget);
    expect(find.text(collection.ratioLabel), findsOneWidget);
    expect(collection.earnedCount, 2);
  });

  testWidgets('獲得済み絞込の行集合が collection.earned と完全一致（未獲得混入なし）',
      (tester) async {
    final owned = <String>[kCrossAppTitles[2].id, kCrossAppTitles[9].id];
    final collection =
        const CrossAppTitleService().build(ownedTitles: owned);
    expect(collection.earnedCount, 2);

    await pumpScreen(tester, ownedTitles: owned);
    await tester.tap(find.byKey(AppKeys.crossAppTitleFilterChip('earned')));
    await tester.pumpAndSettle();

    final earnedIds = collection.earned.map((e) => e.id).toSet();
    for (final entry in collection.entries) {
      final row = find.byKey(AppKeys.crossAppTitleRow(entry.id));
      if (earnedIds.contains(entry.id)) {
        expect(row, findsOneWidget, reason: '獲得行が消えた: ${entry.id}');
      } else {
        expect(row, findsNothing, reason: '未獲得行が混入: ${entry.id}');
      }
    }
  });

  testWidgets('未獲得絞込では獲得行が消え、空にならない', (tester) async {
    final owned = <String>[kCrossAppTitles[0].id];
    final collection =
        const CrossAppTitleService().build(ownedTitles: owned);

    await pumpScreen(tester, ownedTitles: owned);
    await tester.tap(find.byKey(AppKeys.crossAppTitleFilterChip('unearned')));
    await tester.pumpAndSettle();

    expect(collection.unearnedCount, 10);
    expect(find.byKey(AppKeys.crossAppTitleRow(owned.first)), findsNothing);
    expect(find.byKey(AppKeys.crossAppTitleEmpty), findsNothing);
  });

  testWidgets('全獲得で100%・ロック0件、全未獲得で0%（0除算なし）', (tester) async {
    final all = kCrossAppTitles.map((d) => d.id).toList();
    await pumpScreen(tester, ownedTitles: all);
    expect(find.text('獲得 11 / 11'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await pumpScreen(tester, ownedTitles: const <String>[]);
    expect(find.text('獲得 0 / 11'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(11));
  });

  testWidgets('注入した定義がサービスまで届く（2件定義・獲得1件）', (tester) async {
    final definitions = <CrossAppTitleDefinition>[
      const CrossAppTitleDefinition(
          id: '検証称号A', eventType: 'book_completed', threshold: 3),
      const CrossAppTitleDefinition(
          id: '検証称号B', eventType: 'unknown_event', threshold: 1500),
    ];
    await pumpScreen(
      tester,
      ownedTitles: const <String>['検証称号A'],
      definitions: definitions,
    );

    expect(find.text('獲得 1 / 2'), findsOneWidget);
    expect(find.byKey(const Key('row_missing_guard')), findsNothing);
    expect(find.text('検証称号A'), findsOneWidget);
    expect(find.text('検証称号B'), findsOneWidget);
    // 条件ラベルは注入した定義値から算出される
    expect(find.text('読了 3冊'), findsOneWidget);
    expect(find.text('unknown_event 1,500'), findsOneWidget);
  });
}
