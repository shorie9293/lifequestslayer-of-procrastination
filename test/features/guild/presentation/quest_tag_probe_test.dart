// 親探針: 札（タグ）機能の合成不変条件（イシコリドメ #156）
//
// 眷属の試練は個別操作のみを撃ちがちなので、親が
//   ①絞込前件数からの集計  ②画面→ダイアログ→コールバックの合成
//   ③タグ×検索語のAND合成  ④VM→リポジトリの永続化到達
// を実データで撃つ。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/presentation/guild_quest_search_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

final DateTime _now = DateTime.utc(2026, 10, 19, 3, 0, 0).toLocal();

Task _task(
  String id,
  String title, {
  QuestRank rank = QuestRank.B,
  List<String> tags = const [],
}) {
  return Task(id: id, title: title, rank: rank, tags: tags);
}

class _CapturingTaskRepo implements ITaskRepository {
  List<Task> saved = [];
  @override
  Future<List<Task>> loadTasks() async => List.of(saved);
  @override
  Future<void> saveTasks(List<Task> tasks) async => saved = List.of(tasks);
  @override
  Future<void> close() async {}
}

class _MockPlayerRepo implements IPlayerRepository {
  Player _player = Player();
  @override
  bool get loadFailedDueToCorruption => false;
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('探針1: 札チップの件数は絞り込み前の全件から集計される', (tester) async {
    final tasks = [
      _task('a', 'ドラゴン討伐', rank: QuestRank.S, tags: ['work']),
      _task('b', '薬草集め', rank: QuestRank.B, tags: ['work', 'private']),
    ];
    await tester.pumpWidget(MaterialApp(
      home: GuildQuestSearchScreen(tasksOverride: tasks, now: _now),
    ));

    // 絞込前: work は2件
    expect(find.text('work (2)'), findsOneWidget);

    // Sランクで絞り込む → 結果は1件だが、チップの件数は全件由来の2のまま
    await tester.tap(find.byKey(AppKeys.guildQuestRankChip('S')));
    await tester.pump();
    final countText =
        tester.widget<Text>(find.byKey(AppKeys.guildQuestResultCount)).data;
    expect(countText, '1件');
    expect(find.text('work (2)'), findsOneWidget);
    expect(find.text('private (1)'), findsOneWidget);
  });

  testWidgets('探針2: 画面→ダイアログ保存→コールバックに正規化済みタグが届く',
      (tester) async {
    final tasks = [_task('a', 'ドラゴン討伐', tags: ['work'])];
    Task? receivedTask;
    List<String>? receivedTags;

    await tester.pumpWidget(MaterialApp(
      home: GuildQuestSearchScreen(
        tasksOverride: tasks,
        now: _now,
        onTagsSaved: (task, tags) {
          receivedTask = task;
          receivedTags = tags;
        },
      ),
    ));

    await tester.tap(find.byKey(AppKeys.questTagEditButton('a')));
    await tester.pumpAndSettle();
    expect(find.text('札（タグ）の編集'), findsOneWidget);

    // 全角で入力 → normalize されて保存されること
    await tester.enterText(find.byKey(AppKeys.questTagInput), 'ＱＵＥＳＴ');
    await tester.tap(find.byKey(AppKeys.questTagAddButton));
    await tester.pump();
    await tester.tap(find.byKey(AppKeys.questTagSaveButton));
    await tester.pumpAndSettle();

    expect(receivedTask?.id, 'a');
    expect(receivedTags, ['work', 'QUEST']);
  });

  testWidgets('探針3: 札の選択と検索語はANDで合成される', (tester) async {
    final tasks = [
      _task('a', 'ドラゴン討伐', tags: ['work']),
      _task('b', 'ドラゴン観察', tags: ['study']),
      _task('c', '薬草集め', tags: ['work']),
    ];
    await tester.pumpWidget(MaterialApp(
      home: GuildQuestSearchScreen(tasksOverride: tasks, now: _now),
    ));

    await tester.enterText(find.byKey(AppKeys.guildQuestSearchField), 'ドラゴン');
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(AppKeys.guildQuestResultCount)).data,
      '2件',
    );

    await tester.tap(find.byKey(AppKeys.guildQuestTagChip('work')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(AppKeys.guildQuestResultCount)).data,
      '1件',
    );
    expect(find.textContaining('ドラゴン討伐'), findsOneWidget);
    expect(find.textContaining('ドラゴン観察'), findsNothing);
  });

  test('探針4: setTaskTags はリポジトリへの保存まで到達する（state更新で終わらない）',
      () async {
    final repo = _CapturingTaskRepo();
    final playerVm = PlayerViewModel(_MockPlayerRepo());
    await playerVm.load();
    final vm = TaskViewModel(repo, playerVm);
    await vm.load();
    vm.setTasks([_task('a', 'ドラゴン討伐')]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    vm.setTaskTags('a', ['work', 'urgent']);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(vm.tasks.first.tags, ['work', 'urgent']);
    expect(repo.saved.first.tags, ['work', 'urgent']);
  });

  test('探針5: 未知のidへのsetTaskTagsは何もしない（例外を投げない）', () async {
    final repo = _CapturingTaskRepo();
    final playerVm = PlayerViewModel(_MockPlayerRepo());
    await playerVm.load();
    final vm = TaskViewModel(repo, playerVm);
    await vm.load();
    vm.setTasks([_task('a', 'ドラゴン討伐', tags: ['work'])]);
    await Future<void>.delayed(Duration.zero);

    vm.setTaskTags('missing', ['x']);
    await Future<void>.delayed(Duration.zero);

    expect(vm.tasks.first.tags, ['work']);
  });
}
