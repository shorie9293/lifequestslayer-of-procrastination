// 削除Undoの配線試練（GuildScreen / GuildBulkActionScreen）。
//
// 実Hiveは使わず、InMemory のリポジトリ実装を注入する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/guild/presentation/guild_bulk_action_screen.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/undo/presentation/undo_snack_bar.dart';

class _InMemoryTaskRepository implements ITaskRepository {
  List<Task> saved = [];

  @override
  Future<List<Task>> loadTasks() async => saved;

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    saved = List<Task>.of(tasks);
  }

  @override
  Future<void> close() async {}
}

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;

  @override
  Future<Player?> loadPlayer() async => Player();

  @override
  Future<void> savePlayer(Player player) async {}

  @override
  Future<void> close() async {}
}

({TaskViewModel task, PlayerViewModel player, _InMemoryTaskRepository repo})
    _createViewModels() {
  final playerVM = PlayerViewModel(_MockPlayerRepository());
  final repo = _InMemoryTaskRepository();
  final taskVM = TaskViewModel(repo, playerVM);
  return (task: taskVM, player: playerVM, repo: repo);
}

Widget _wrap(Widget child,
    {required TaskViewModel task, required PlayerViewModel player}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<TaskViewModel>.value(value: task),
      ChangeNotifierProvider<PlayerViewModel>.value(value: player),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('GuildScreen 削除Undo', () {
    testWidgets('破棄 → SnackBar 表示 → 元に戻す でタスクが復元される', (tester) async {
      final vms = _createViewModels();
      // 期限12時間以内 = 緊急セクションに出る（破棄ボタンが1つに定まる）
      final deadline = DateTime.now().add(const Duration(hours: 12));
      vms.task.setTasks([
        Task(
          id: 't1',
          title: '破棄対象クエスト',
          status: TaskStatus.inGuild,
          rank: QuestRank.A,
          deadline: deadline,
        ),
      ]);

      await tester.pumpWidget(
          _wrap(const GuildScreen(), task: vms.task, player: vms.player));
      await tester.pump();

      expect(find.textContaining('破棄対象クエスト'), findsOneWidget);

      // 破棄 → 確認ダイアログ（既存文言）→ 破棄する
      await tester.tap(find.byKey(AppKeys.urgentDelete));
      await tester.pumpAndSettle();
      expect(find.text('クエストを破棄'), findsOneWidget);
      await tester.tap(find.text('破棄する'));
      await tester.pumpAndSettle();

      // 削除は即時実行のまま
      expect(vms.task.tasks.where((t) => t.id == 't1'), isEmpty);
      // Undo 付き SnackBar
      expect(find.text('クエストを削除しました'), findsOneWidget);
      expect(find.byKey(undoActionKey), findsOneWidget);

      // 元に戻す → 復元
      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      expect(vms.task.tasks.where((t) => t.id == 't1'), hasLength(1));
      final restored = vms.task.tasks.firstWhere((t) => t.id == 't1');
      expect(restored.title, '破棄対象クエスト');
      expect(restored.rank, QuestRank.A);
      expect(restored.deadline, deadline);
      // 画面にも戻っている
      expect(find.textContaining('破棄対象クエスト'), findsOneWidget);
    });
  });

  group('GuildBulkActionScreen 一括削除Undo', () {
    testWidgets('一括破棄 → 元に戻す で全件復元される', (tester) async {
      final vms = _createViewModels();
      vms.task.setTasks([
        Task(id: 'g1', title: 'クエストA', status: TaskStatus.inGuild),
        Task(id: 'g2', title: 'クエストB', status: TaskStatus.inGuild),
        Task(id: 'g3', title: 'クエストC', status: TaskStatus.inGuild),
      ]);

      await tester.pumpWidget(_wrap(
        GuildBulkActionScreen(tasksOverride: vms.task.guildTasks),
        task: vms.task,
        player: vms.player,
      ));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.guildBulkSelectAll));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.guildBulkActionDelete));
      await tester.pumpAndSettle();

      expect(vms.task.tasks, isEmpty);
      expect(find.text('クエストを削除しました'), findsOneWidget);
      expect(find.byKey(undoActionKey), findsOneWidget);

      await tester.tap(find.byKey(undoActionKey));
      await tester.pumpAndSettle();

      expect(vms.task.tasks.map((t) => t.id).toSet(), {'g1', 'g2', 'g3'});
    });

    testWidgets('Undo を押さずに破棄すれば復元されない', (tester) async {
      final vms = _createViewModels();
      vms.task.setTasks([
        Task(id: 'g1', title: 'クエストA', status: TaskStatus.inGuild),
      ]);

      await tester.pumpWidget(_wrap(
        GuildBulkActionScreen(tasksOverride: vms.task.guildTasks),
        task: vms.task,
        player: vms.player,
      ));
      await tester.pump();

      await tester.tap(find.byKey(AppKeys.guildBulkSelectAll));
      await tester.pump();
      await tester.tap(find.byKey(AppKeys.guildBulkActionDelete));
      await tester.pumpAndSettle();

      expect(vms.task.tasks, isEmpty);
    });
  });
}
