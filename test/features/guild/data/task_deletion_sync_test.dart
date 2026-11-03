// 削除同期の安全性（差分削除の廃止）を守る試練。
//
// 背景: 旧 saveTasks は「クラウドにあって手元にないIDを削除」していた。
// 手元が古い一覧のまま保存されると、他端末や API が入れた行まで消える。
// 削除は deleteTasks() の明示呼び出しだけに限定する。
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_deletion_repository.dart';
import 'package:rpg_todo/features/guild/data/hybrid_task_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class _RecordingTaskRepo implements ITaskRepository, ITaskDeletionRepository {
  _RecordingTaskRepo({List<Task>? initial}) : store = List<Task>.of(initial ?? []);

  List<Task> store;
  final List<List<String>> deleteCalls = <List<String>>[];
  int saveCalls = 0;

  @override
  Future<List<Task>> loadTasks() async => List<Task>.of(store);

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    saveCalls++;
    // 本番の Supabase 実装と同じ「upsert（渡された分だけ上書き）」に揃える。
    // 全置換にすると「渡されないIDは消さない」ことを検証できない。
    final byId = <String, Task>{for (final t in store) t.id: t};
    for (final t in tasks) {
      byId[t.id] = t;
    }
    store = byId.values.toList();
  }

  @override
  Future<void> deleteTasks(List<String> ids) async {
    deleteCalls.add(List<String>.of(ids));
    store.removeWhere((t) => ids.contains(t.id));
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

Task _task(String id) => Task(id: id, title: id);

void main() {
  group('HybridTaskRepository.deleteTasks', () {
    test('ローカルとクラウドの両方へ削除を伝える', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('a'), _task('b')]);
      final cloud = _RecordingTaskRepo(initial: <Task>[_task('a'), _task('b')]);
      final repo = HybridTaskRepository(hiveRepo: hive, supabaseRepo: cloud);

      await repo.deleteTasks(<String>['a']);

      expect(hive.deleteCalls, <List<String>>[
        <String>['a']
      ]);
      expect(cloud.deleteCalls, <List<String>>[
        <String>['a']
      ]);
      expect(hive.store.map((t) => t.id), <String>['b']);
    });

    test('空のIDリストでは何もしない', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('a')]);
      final cloud = _RecordingTaskRepo(initial: <Task>[_task('a')]);
      final repo = HybridTaskRepository(hiveRepo: hive, supabaseRepo: cloud);

      await repo.deleteTasks(const <String>[]);

      expect(hive.deleteCalls, isEmpty);
      expect(cloud.deleteCalls, isEmpty);
    });

    test('saveTasks は暗黙の削除を行わない（渡されないIDは消さない）', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('a'), _task('b')]);
      final cloud = _RecordingTaskRepo(initial: <Task>[_task('a'), _task('b')]);
      final repo = HybridTaskRepository(hiveRepo: hive, supabaseRepo: cloud);

      await repo.saveTasks(<Task>[_task('a')]);

      expect(hive.deleteCalls, isEmpty);
      expect(cloud.deleteCalls, isEmpty);
      // クラウドには 'b' が残る（＝他端末/APIが入れた行を巻き込まない）
      expect(cloud.store.map((t) => t.id), containsAll(<String>['a', 'b']));
    });
  });

  group('TaskViewModel.deleteTask', () {
    test('リポジトリへ明示削除を伝え、一覧からも消える', () async {
      final repo = _RecordingTaskRepo(initial: <Task>[_task('a'), _task('b')]);
      final vm = TaskViewModel(repo, PlayerViewModel(_PlayerRepo()));
      vm.setTasks(<Task>[_task('a'), _task('b')]);

      vm.deleteTask('a');
      await Future<void>.delayed(Duration.zero);

      expect(repo.deleteCalls, <List<String>>[
        <String>['a']
      ]);
      expect(vm.tasks.map((t) => t.id), <String>['b']);
    });
  });
}
