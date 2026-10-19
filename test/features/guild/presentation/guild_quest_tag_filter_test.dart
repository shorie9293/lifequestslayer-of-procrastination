// 検索画面のタグ絞り込みチップ＋札編集導線の試練
//
// tasksOverride（と任意の onTagsSaved）だけで pump する。Provider 不要。
// 基準時刻は DateTime.utc(...).toLocal() から作り、TZ=UTC でも緑になるようにする。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';

/// TZ 非依存の固定基準時刻
final DateTime _now = DateTime.utc(2026, 9, 22, 3, 0, 0).toLocal();

Task _task(
  String id,
  String title, {
  QuestRank rank = QuestRank.B,
  DateTime? deadline,
  List<String> tags = const [],
}) {
  return Task(id: id, title: title, rank: rank, deadline: deadline, tags: tags);
}

/// 札の件数: 戦闘=2, 冒険=1, 採集=1
List<Task> _taggedTasks() => [
      _task('t1', 'ゴブリン討伐', tags: ['戦闘']),
      _task('t2', 'ドラゴン討伐', rank: QuestRank.S, tags: ['戦闘', '冒険']),
      _task('t3', '薬草採取', rank: QuestRank.A, tags: ['採集']),
      _task('t4', '報告書作成', deadline: _now.add(const Duration(days: 3))),
    ];

List<Task> _untaggedTasks() => [
      _task('u1', 'ゴブリン討伐'),
      _task('u2', '薬草採取', rank: QuestRank.A),
    ];

Future<void> _pump(
  WidgetTester tester, {
  required List<Task> tasks,
  void Function(Task task, List<String> tags)? onTagsSaved,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: GuildQuestSearchScreen(
        tasksOverride: tasks,
        now: _now,
        onTagsSaved: onTagsSaved,
      ),
    ),
  );
  await tester.pump();
}

int _filterChipCount(WidgetTester tester) =>
    tester.widgetList<FilterChip>(find.byType(FilterChip)).length;

void main() {
  testWidgets('タグチップが件数付きで表示される', (tester) async {
    await _pump(tester, tasks: _taggedTasks());

    expect(find.byKey(AppKeys.guildQuestTagChip('戦闘')), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestTagChip('冒険')), findsOneWidget);
    expect(find.byKey(AppKeys.guildQuestTagChip('採集')), findsOneWidget);
    expect(find.text('戦闘 (2)'), findsOneWidget);
    expect(find.text('冒険 (1)'), findsOneWidget);
    expect(find.text('採集 (1)'), findsOneWidget);
  });

  testWidgets('タグ選択で結果が絞られる', (tester) async {
    await _pump(tester, tasks: _taggedTasks());
    expect(find.text('4件'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildQuestTagChip('戦闘')));
    await tester.pump();

    expect(find.text('2件'), findsOneWidget);
    expect(find.text('[B] ゴブリン討伐'), findsOneWidget);
    expect(find.text('[S] ドラゴン討伐'), findsOneWidget);
    expect(find.text('[A] 薬草採取'), findsNothing);
  });

  testWidgets('タグ2つ選択は OR で絞られる', (tester) async {
    await _pump(tester, tasks: _taggedTasks());

    await tester.tap(find.byKey(AppKeys.guildQuestTagChip('戦闘')));
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.guildQuestTagChip('採集')));
    await tester.pump();

    expect(find.text('3件'), findsOneWidget);
    expect(find.text('[A] 薬草採取'), findsOneWidget);
    expect(find.text('[B] 報告書作成'), findsNothing);
  });

  testWidgets('リセットでタグ選択も解除される', (tester) async {
    await _pump(tester, tasks: _taggedTasks());

    await tester.tap(find.byKey(AppKeys.guildQuestTagChip('戦闘')));
    await tester.pump();
    expect(find.text('2件'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildQuestSearchReset));
    await tester.pump();

    expect(find.text('4件'), findsOneWidget);
    final chip = tester.widget<FilterChip>(
      find.byKey(AppKeys.guildQuestTagChip('戦闘')),
    );
    expect(chip.selected, isFalse);
  });

  testWidgets('タグ0件ならタグチップ行は出ない', (tester) async {
    await _pump(tester, tasks: _untaggedTasks());

    // 状態3 + ランク3 の 6 個のみ（タグチップが増えていない）
    expect(_filterChipCount(tester), 6);
    expect(find.textContaining(' (1)'), findsNothing);
  });

  testWidgets('tasksOverride + onTagsSaved なら編集ボタンが出て保存がコールバックに届く',
      (tester) async {
    final saved = <String, List<String>>{};
    await _pump(
      tester,
      tasks: _taggedTasks(),
      onTagsSaved: (task, tags) => saved[task.id] = tags,
    );

    expect(find.byKey(AppKeys.questTagEditButton('t1')), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.questTagEditButton('t1')));
    await tester.pumpAndSettle();

    expect(find.text('札（タグ）の編集'), findsOneWidget);
    await tester.enterText(find.byKey(AppKeys.questTagInput), '採集');
    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.questTagSaveButton));
    await tester.pumpAndSettle();

    expect(saved['t1'], ['戦闘', '採集']);
  });

  testWidgets('onTagsSaved 未指定なら編集ボタンは出ない（既存試練の互換）', (tester) async {
    await _pump(tester, tasks: _taggedTasks());

    expect(find.byKey(AppKeys.questTagEditButton('t1')), findsNothing);
  });
}
