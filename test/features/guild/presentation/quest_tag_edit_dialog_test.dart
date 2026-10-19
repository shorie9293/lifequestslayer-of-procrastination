// 札（タグ）編集ダイアログの試練
//
// Provider 不要。Dialog を直接 showDialog で開き、onSave の受け取りを検証する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/quest_tag_edit_dialog.dart';

/// ダイアログを開き、onSave で受け取った内容を蓄積するリストを返す。
Future<List<List<String>>> _open(
  WidgetTester tester, {
  List<String> initialTags = const [],
  String taskTitle = 'ゴブリン討伐',
}) async {
  final saved = <List<String>>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => QuestTagEditDialog(
                taskTitle: taskTitle,
                initialTags: initialTags,
                onSave: saved.add,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('初期札が Chip で表示され、クエスト名も出る', (tester) async {
    await _open(tester, initialTags: ['戦闘', '冒険']);

    expect(find.text('札（タグ）の編集'), findsOneWidget);
    expect(find.text('ゴブリン討伐'), findsOneWidget);
    expect(find.byKey(AppKeys.questTagChipDelete('戦闘')), findsOneWidget);
    expect(find.byKey(AppKeys.questTagChipDelete('冒険')), findsOneWidget);
    expect(find.byKey(AppKeys.questTagEmpty), findsNothing);
  });

  testWidgets('札が無ければ「まだ札がない。」が出る', (tester) async {
    await _open(tester);

    expect(find.byKey(AppKeys.questTagEmpty), findsOneWidget);
    expect(find.text('まだ札がない。'), findsOneWidget);
  });

  testWidgets('追加すると Chip が増え、入力欄がクリアされる', (tester) async {
    await _open(tester);

    await tester.enterText(find.byKey(AppKeys.questTagInput), '採集');
    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();

    expect(find.byKey(AppKeys.questTagChipDelete('採集')), findsOneWidget);
    expect(find.byKey(AppKeys.questTagError), findsNothing);
    final field = tester.widget<TextField>(find.byKey(AppKeys.questTagInput));
    expect(field.controller?.text ?? '', '');
  });

  testWidgets('空文字の追加はエラー「札を入力せよ」', (tester) async {
    await _open(tester);

    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();

    expect(find.byKey(AppKeys.questTagError), findsOneWidget);
    expect(find.text('札を入力せよ'), findsOneWidget);
    expect(find.byKey(AppKeys.questTagEmpty), findsOneWidget);
  });

  testWidgets('13文字の追加はエラー「12文字まで」', (tester) async {
    await _open(tester);

    await tester.enterText(find.byKey(AppKeys.questTagInput), 'あ' * 13);
    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();

    expect(find.byKey(AppKeys.questTagError), findsOneWidget);
    expect(find.text('12文字まで'), findsOneWidget);
    expect(find.byKey(AppKeys.questTagChipDelete('あ' * 13)), findsNothing);
  });

  testWidgets('重複（大文字小文字違い含む）はエラー「同じ札が既にある」', (tester) async {
    await _open(tester, initialTags: ['Battle']);

    await tester.enterText(find.byKey(AppKeys.questTagInput), 'battle');
    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();

    expect(find.byKey(AppKeys.questTagError), findsOneWidget);
    expect(find.text('同じ札が既にある'), findsOneWidget);
    // 既存の1件のみ（重複追加されていない）
    expect(find.byKey(AppKeys.questTagChipDelete('Battle')), findsOneWidget);
    expect(find.byKey(AppKeys.questTagChipDelete('battle')), findsNothing);
  });

  testWidgets('保存で onSave が更新後のリストを受け、ダイアログが閉じる', (tester) async {
    final saved = await _open(tester, initialTags: ['戦闘']);

    await tester.enterText(find.byKey(AppKeys.questTagInput), '採集');
    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.questTagSaveButton));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single, ['戦闘', '採集']);
    expect(find.byKey(AppKeys.questTagSaveButton), findsNothing);
  });

  testWidgets('キャンセルでは onSave が呼ばれない', (tester) async {
    final saved = await _open(tester, initialTags: ['戦闘']);

    await tester.enterText(find.byKey(AppKeys.questTagInput), '採集');
    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(saved, isEmpty);
    expect(find.byKey(AppKeys.questTagSaveButton), findsNothing);
  });

  testWidgets('削除すると Chip が消える', (tester) async {
    await _open(tester, initialTags: ['戦闘', '冒険']);

    await tester.tap(
      find.descendant(
        of: find.byKey(AppKeys.questTagChipDelete('戦闘')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();

    expect(find.byKey(AppKeys.questTagChipDelete('戦闘')), findsNothing);
    expect(find.byKey(AppKeys.questTagChipDelete('冒険')), findsOneWidget);
  });
}
