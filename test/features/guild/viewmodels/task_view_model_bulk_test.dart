// 一括操作（改善提案 #91）の TaskViewModel 試練
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

class _MockTaskRepo implements ITaskRepository {
  final List<Task> _tasks = [];
  @override
  Future<List<Task>> loadTasks() async => List.from(_tasks);
  @override
  Future<void> saveTasks(List<Task> tasks) async {
    _tasks.clear();
    _tasks.addAll(tasks);
  }
  @override
  Future<void> close() async {}
}

void main() {
  // IDは uuid v4 で非決定的 → タイトルから解決する
  String idOf(TaskViewModel target, String title) =>
      target.tasks.firstWhere((t) => t.title == title).id;

  late PlayerViewModel playerVm;
  late TaskViewModel vm;
  late _MockTaskRepo repo;

  setUp(() async {
    repo = _MockTaskRepo();
    playerVm = PlayerViewModel(_MockPlayerRepo());
    await playerVm.load();
    vm = TaskViewModel(repo, playerVm);
    await vm.load();
    for (final title in ['a', 'b', 'c', 'd']) {
      vm.addTask(title);
    }
  });

  group('deleteTasks', () {
    test('選択した複数クエストを一括破棄する', () {
      final removed = vm.deleteTasks([idOf(vm, 'a'), idOf(vm, 'b')]);
      expect(removed, 2);
      expect(vm.tasks.map((t) => t.title), containsAll(['c', 'd']));
      expect(vm.tasks, hasLength(2));
    });

    test('存在しないIDはスキップされ破棄件数が減る', () {
      final removed = vm.deleteTasks([idOf(vm, 'a'), 'unknown']);
      expect(removed, 1);
    });

    test('空ID集合は何もせず0を返す', () {
      expect(vm.deleteTasks(const []), 0);
      expect(vm.tasks, hasLength(4));
    });

    test('破棄後はリポジトリに保存される（合成: 削除→再取得）', () async {
      vm.deleteTasks([idOf(vm, 'a'), idOf(vm, 'b')]);
      // _autoSave は非同期のため保存完了を待つ
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final persisted = await repo.loadTasks();
      expect(persisted, hasLength(2));
    });
  });

  group('postponeTasks', () {
    test('期限なしの選択分は基準時刻からN日後に設定する', () {
      final now = DateTime(2026, 10, 6, 9);
      final postponed = vm.postponeTasks([idOf(vm, 'a'), idOf(vm, 'b')], 3, now: now);
      expect(postponed, 2);
      expect(vm.tasks.firstWhere((t) => t.title == 'a').deadline,
          DateTime(2026, 10, 9, 9));
    });

    test('期限ありの選択分は既存期限からN日延長する', () {
      final i = vm.tasks.indexWhere((t) => t.title == 'a');
      vm.tasks[i].deadline = DateTime(2026, 10, 10);
      vm.postponeTasks([idOf(vm, 'a')], 7, now: DateTime(2026, 10, 6));
      expect(vm.tasks.firstWhere((t) => t.title == 'a').deadline,
          DateTime(2026, 10, 17));
    });

    test('0日以下は何もしない', () {
      expect(vm.postponeTasks([idOf(vm, 'a')], 0), 0);
      expect(vm.postponeTasks([idOf(vm, 'a')], -1), 0);
      expect(vm.tasks.firstWhere((t) => t.title == 'a').deadline, isNull);
    });

    test('延期後はリポジトリに保存される（合成: 延期→再取得）', () async {
      vm.postponeTasks([idOf(vm, 'a'), idOf(vm, 'c')], 1, now: DateTime(2026, 10, 6));
      // _autoSave は非同期のため保存完了を待つ
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final persisted = await repo.loadTasks();
      expect(
          persisted.firstWhere((t) => t.title == 'a').deadline, isNotNull);
    });
  });

  group('acceptTasks', () {
    test('選択した複数クエストを一括出発する', () {
      final accepted = vm.acceptTasks([idOf(vm, 'a'), idOf(vm, 'b')], debugMode: true);
      expect(accepted, 2);
      expect(
          vm.tasks.where((t) => t.status == TaskStatus.active), hasLength(2));
    });

    test('存在しないIDはスキップされる', () {
      final accepted = vm.acceptTasks([idOf(vm, 'a'), 'unknown'], debugMode: true);
      expect(accepted, 1);
    });
  });
}
