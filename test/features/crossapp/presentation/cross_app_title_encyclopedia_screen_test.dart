// クロスアプリ称号図鑑画面の試練。
//
// ownedTitles を注入して Provider 不要経路で pump し、サマリー・絞り込み・
// グループ表示・空状態・獲得状態の描画を検証する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';
import 'package:rpg_todo/features/crossapp/presentation/cross_app_title_encyclopedia_screen.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<String> ownedTitles,
}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: CrossAppTitleEncyclopediaScreen(ownedTitles: ownedTitles),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

double _progressValue(WidgetTester tester) {
  final indicator = tester.widget<LinearProgressIndicator>(
    find.descendant(
      of: find.byKey(AppKeys.crossAppTitleSummary),
      matching: find.byType(LinearProgressIndicator),
    ),
  );
  return indicator.value!;
}

void main() {
  testWidgets('ownedTitles 注入で全15行が表示される', (tester) async {
    await _pump(tester, ownedTitles: const []);
    for (final def in kCrossAppTitles) {
      expect(find.byKey(AppKeys.crossAppTitleRow(def.id)), findsOneWidget);
    }
    expect(kCrossAppTitles.length, 15);
  });

  testWidgets('サマリーに「獲得 2 / 15」と達成率が出る', (tester) async {
    await _pump(tester, ownedTitles: const ['読書家の卵', '知識の探求者']);
    expect(find.byKey(AppKeys.crossAppTitleSummary), findsOneWidget);
    expect(find.text('獲得 2 / 15'), findsOneWidget);
    expect(find.text('13%'), findsOneWidget);
    expect(_progressValue(tester), closeTo(2 / 15, 0.001));
  });

  testWidgets('獲得行にはロックアイコンが出ず、未獲得行には出る', (tester) async {
    await _pump(tester, ownedTitles: const ['読書家の卵']);
    expect(
      find.descendant(
        of: find.byKey(AppKeys.crossAppTitleRow('読書家の卵')),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(AppKeys.crossAppTitleRow('読書家の卵')),
        matching: find.byIcon(Icons.military_tech),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(AppKeys.crossAppTitleRow('書庫の冒険者')),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsOneWidget,
    );
  });

  testWidgets('獲得済みで絞り込むと獲得行のみ残る', (tester) async {
    await _pump(tester, ownedTitles: const ['読書家の卵', '知識の探求者']);
    await tester.tap(
      find.byKey(AppKeys.crossAppTitleFilterChip('earned')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.crossAppTitleRow('読書家の卵')), findsOneWidget);
    expect(find.byKey(AppKeys.crossAppTitleRow('書庫の冒険者')), findsNothing);
    expect(find.text('獲得 2 / 15'), findsOneWidget);
  });

  testWidgets('未獲得で絞り込み0件なら空状態を表示する', (tester) async {
    final all = kCrossAppTitles.map((d) => d.id).toList();
    await _pump(tester, ownedTitles: all);
    await tester.tap(
      find.byKey(AppKeys.crossAppTitleFilterChip('unearned')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.crossAppTitleEmpty), findsOneWidget);
    expect(find.text('該当する称号はありません'), findsOneWidget);
  });

  testWidgets('全獲得なら ratioLabel が 100%・progress が 1.0', (tester) async {
    final all = kCrossAppTitles.map((d) => d.id).toList();
    await _pump(tester, ownedTitles: all);
    expect(find.text('獲得 15 / 15'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(_progressValue(tester), 1.0);
  });

  testWidgets('全未獲得なら ratioLabel が 0%（0除算なし）', (tester) async {
    await _pump(tester, ownedTitles: const []);
    expect(find.text('獲得 0 / 15'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(_progressValue(tester), 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('グループ見出しが定義順（読了冊数→連続読書日数→獲得XP→読了ページ数）', (tester) async {
    await _pump(tester, ownedTitles: const []);
    final labels = ['読了冊数', '連続読書日数', '獲得XP', '読了ページ数'];
    final offsets =
        labels.map((l) => tester.getTopLeft(find.text(l)).dy).toList();
    for (var i = 0; i < offsets.length - 1; i++) {
      expect(offsets[i], lessThan(offsets[i + 1]),
          reason: '${labels[i]} は ${labels[i + 1]} より上にあるべき');
    }
  });

  testWidgets('条件ラベル（読了 50冊 / XP 10,000）が表示される', (tester) async {
    await _pump(tester, ownedTitles: const []);
    expect(
      find.descendant(
        of: find.byKey(AppKeys.crossAppTitleRow('千巻の賢者')),
        matching: find.text('読了 50冊'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(AppKeys.crossAppTitleRow('知の航海者')),
        matching: find.text('XP 10,000'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('獲得状態ラベル（獲得済み / 未獲得）が行に出る', (tester) async {
    await _pump(tester, ownedTitles: const ['読書家の卵']);
    expect(
      find.descendant(
        of: find.byKey(AppKeys.crossAppTitleRow('読書家の卵')),
        matching: find.text('獲得済み'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(AppKeys.crossAppTitleRow('書庫の冒険者')),
        matching: find.text('未獲得'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('フィルタチップの選択状態が切り替わる', (tester) async {
    await _pump(tester, ownedTitles: const ['読書家の卵']);

    FilterChip chipOf(String name) => tester.widget<FilterChip>(
          find.byKey(AppKeys.crossAppTitleFilterChip(name)),
        );

    expect(chipOf('all').selected, isTrue);
    expect(chipOf('earned').selected, isFalse);

    await tester.tap(find.byKey(AppKeys.crossAppTitleFilterChip('earned')));
    await tester.pumpAndSettle();

    expect(chipOf('all').selected, isFalse);
    expect(chipOf('earned').selected, isTrue);

    await tester.tap(find.byKey(AppKeys.crossAppTitleFilterChip('all')));
    await tester.pumpAndSettle();
    expect(chipOf('all').selected, isTrue);
    expect(find.byKey(AppKeys.crossAppTitleRow('書庫の冒険者')), findsOneWidget);
  });

  testWidgets('未獲得行に「未獲得」表示があり例外が出ない', (tester) async {
    await _pump(tester, ownedTitles: const []);
    expect(find.byKey(AppKeys.crossAppTitleRow('万頁の読破者')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
