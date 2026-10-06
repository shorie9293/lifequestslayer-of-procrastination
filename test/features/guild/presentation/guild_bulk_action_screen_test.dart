// 一括操作画面（改善提案 #91）のウィジェット試練
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_bulk_action.dart';
import 'package:rpg_todo/features/guild/presentation/guild_bulk_action_screen.dart';

void main() {
  final tasks = [
    Task(id: 'g1', title: 'クエストA', status: TaskStatus.inGuild),
    Task(id: 'g2', title: 'クエストB', status: TaskStatus.inGuild),
    Task(id: 'g3', title: 'クエストC', status: TaskStatus.inGuild),
    Task(id: 'a1', title: '出発済み', status: TaskStatus.active),
  ];

  Future<void> pump(WidgetTester tester,
      {required GuildBulkApplyHandler handler}) async {
    await tester.pumpWidget(MaterialApp(
      home: GuildBulkActionScreen(
        tasksOverride: tasks,
        applyOverride: handler,
      ),
    ));
  }

  testWidgets('初期表示: 選択0件・対象は未受注3件のみ', (tester) async {
    await pump(tester, handler: (_, __) => 0);
    expect(find.byKey(AppKeys.guildBulkScreen), findsOneWidget);
    final label =
        tester.widget<Text>(find.byKey(AppKeys.guildBulkCountLabel)).data!;
    expect(label, contains('選択: 0件'));
    expect(label, contains('対象: 3件'));
    expect(find.byKey(AppKeys.guildBulkRow('g1')), findsOneWidget);
    expect(find.byKey(AppKeys.guildBulkRow('a1')), findsNothing);
  });

  testWidgets('行タップで選択が積み上がり、件数表示が追随する', (tester) async {
    await pump(tester, handler: (_, __) => 0);
    await tester.tap(find.byKey(AppKeys.guildBulkRow('g1')));
    await tester.pump();
    final afterOne =
        tester.widget<Text>(find.byKey(AppKeys.guildBulkCountLabel)).data!;
    expect(afterOne, contains('選択: 1件'));

    await tester.tap(find.byKey(AppKeys.guildBulkSelectAll));
    await tester.pump();
    final afterAll =
        tester.widget<Text>(find.byKey(AppKeys.guildBulkCountLabel)).data!;
    expect(afterAll, contains('選択: 3件'));

    await tester.tap(find.byKey(AppKeys.guildBulkClearSelection));
    await tester.pump();
    final afterClear =
        tester.widget<Text>(find.byKey(AppKeys.guildBulkCountLabel)).data!;
    expect(afterClear, contains('選択: 0件'));
  });

  testWidgets('破棄ボタン: 選択集合が純粋計画を経由して適用される（合成の不変条件）', (tester) async {
    final calls = <GuildBulkAction, Set<String>>{};
    await pump(tester, handler: (action, ids) {
      calls[action] = Set<String>.of(ids);
      return ids.length;
    });
    await tester.tap(find.byKey(AppKeys.guildBulkSelectAll));
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.guildBulkActionDelete));
    await tester.pump();
    expect(calls[GuildBulkAction.delete], containsAll(['g1', 'g2', 'g3']));
    expect(calls[GuildBulkAction.delete]!, isNot(contains('a1')));
    // 適用後は選択解除される
    final label =
        tester.widget<Text>(find.byKey(AppKeys.guildBulkCountLabel)).data!;
    expect(label, contains('選択: 0件'));
    expect(find.text('3件を破棄しました。'), findsOneWidget);
  });

  testWidgets('未選択で操作すると案内が出て適用されない', (tester) async {
    var called = 0;
    await pump(tester, handler: (_, __) {
      called++;
      return 0;
    });
    await tester.tap(find.byKey(AppKeys.guildBulkActionAccept));
    await tester.pump();
    expect(called, 0);
    expect(find.text('対象のクエストを選択してください。'), findsOneWidget);
  });

  testWidgets('延期チップの選択が切り替わる', (tester) async {
    await pump(tester, handler: (_, __) => 0);
    final chip3 =
        tester.widget<ChoiceChip>(find.byKey(AppKeys.guildBulkPostponeChip(3)));
    expect(chip3.selected, isFalse);
    await tester.tap(find.byKey(AppKeys.guildBulkPostponeChip(3)));
    await tester.pump();
    final chip3After =
        tester.widget<ChoiceChip>(find.byKey(AppKeys.guildBulkPostponeChip(3)));
    expect(chip3After.selected, isTrue);
  });

  testWidgets('出発ボタン: 対象は未受注のみで適用件数が返る', (tester) async {
    final calls = <GuildBulkAction, Set<String>>{};
    await pump(tester, handler: (action, ids) {
      calls[action] = Set<String>.of(ids);
      return ids.length;
    });
    await tester.tap(find.byKey(AppKeys.guildBulkRow('g1')));
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.guildBulkActionAccept));
    await tester.pump();
    expect(calls[GuildBulkAction.accept], {'g1'});
    expect(find.text('1件を出発しました。'), findsOneWidget);
  });
}
