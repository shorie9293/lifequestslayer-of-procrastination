// 親探針: 削除Undoの合成不変条件（眷属の配線試練が撃たない点）。
//
// 1) Undo が「state 更新だけで終わらず」リポジトリ保存まで到達するか
//    （InMemoryTaskRepository.saved を実測＝再起動後も残る）。
// 2) 復元位置（元の並び位置へ戻るか・末尾へ落ちるか）を実測して固定する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/undo/presentation/undo_snack_bar.dart';

class _Repo implements ITaskRepository {
  List<Task> saved = [];
  int saveCalls = 0;

  @override
  Future<List<Task>> loadTasks() async => List<Task>.of(saved);

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    saved = List<Task>.of(tasks);
    saveCalls++;
  }

  @override
  Future<void> close() async {}
}

class _PlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;

  @override
  Future<Player?> loadPlayer() async => Player();

  @override
  Future<void> savePlayer(Player player) async {}

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets('親探針: Undo はリポジトリ保存まで到達し、元の並び位置へ戻る', (tester) async {
    final playerVM = PlayerViewModel(_PlayerRepo());
    final repo = _Repo();
    final taskVM = TaskViewModel(repo, playerVM);

    final urgentDeadline = DateTime.now().add(const Duration(hours: 12));
    taskVM.setTasks([
      Task(id: 'a', title: 'Aクエスト', status: TaskStatus.inGuild),
      Task(
        id: 'target',
        title: '破棄対象',
        status: TaskStatus.inGuild,
        rank: QuestRank.A,
        deadline: urgentDeadline,
      ),
      Task(id: 'z', title: 'Zクエスト', status: TaskStatus.inGuild),
    ]);
    repo.saveCalls = 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TaskViewModel>.value(value: taskVM),
          ChangeNotifierProvider<PlayerViewModel>.value(value: playerVM),
        ],
        child: const MaterialApp(home: GuildScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(AppKeys.urgentDelete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('破棄する'));
    await tester.pumpAndSettle();
    expect(taskVM.tasks.map((t) => t.id), isNot(contains('target')));

    await tester.tap(find.byKey(undoActionKey));
    await tester.pumpAndSettle();

    // 1) 復元が state だけでなくリポジトリ保存へ到達している
    expect(repo.saved.map((t) => t.id), contains('target'),
        reason: 'Undo 後のタスクが永続化されていない（state更新のみ）');

    // 2) 復元位置は元の並び（A, target, Z）
    expect(taskVM.tasks.map((t) => t.id).toList(), ['a', 'target', 'z'],
        reason: '復元位置が元の並びと異なる');
    final restored = taskVM.tasks.firstWhere((t) => t.id == 'target');
    expect(restored.deadline, urgentDeadline);
  });
}
