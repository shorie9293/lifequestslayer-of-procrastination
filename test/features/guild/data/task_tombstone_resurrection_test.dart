// 削除したクエストが「復活する」禍津の回帰試練。
//
// 背景（実測）: 削除はローカル/クラウド双方から行を消せている（DB直査で確認）。
// しかし cron（創造主タスク自動登録）や他端末が同じ id を再登録すると、
// HybridTaskRepository のマージ規則「クラウドにのみ存在 → ローカルへ追加」が
// それを復元してしまう。さらに削除要求は投げっぱなしで、失敗すると行が残り
// 以後ずっと復活する。
//
// 対策: 削除時に「墓標（tombstone）」を先に書き、マージは墓標の id を採用せず
// クラウド側の行も掃除する。
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_task_deletion_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_tombstone_repository.dart';
import 'package:rpg_todo/features/guild/data/hybrid_task_repository.dart';

class _RecordingTaskRepo implements ITaskRepository, ITaskDeletionRepository {
  _RecordingTaskRepo({List<Task>? initial})
      : store = List<Task>.of(initial ?? <Task>[]);

  List<Task> store;
  final List<List<String>> deleteCalls = <List<String>>[];
  final List<List<String>> saveCalls = <List<String>>[];

  @override
  Future<List<Task>> loadTasks() async => List<Task>.of(store);

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    saveCalls.add(tasks.map((t) => t.id).toList());
    // 本番の upsert と同じ「渡された分だけ上書き」
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

class _MemoryTombstones implements ITaskTombstoneRepository {
  final Set<String> ids = <String>{};
  bool failOnMark = false;
  int markCalls = 0;

  @override
  Future<void> markDeleted(Iterable<String> taskIds, {String? source}) async {
    markCalls++;
    if (failOnMark) throw StateError('offline');
    ids.addAll(taskIds);
  }

  @override
  Future<Set<String>> loadTombstones() async => Set<String>.of(ids);

  @override
  Future<void> clear(Iterable<String> taskIds) async {
    ids.removeAll(taskIds);
  }
}

Task _task(String id, {DateTime? updatedAt}) =>
    Task(id: id, title: id, updatedAt: updatedAt);

void main() {
  group('削除の墓標', () {
    test('deleteTasks は墓標を先に書き、ローカルとクラウドの両方から消す', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('a'), _task('b')]);
      final cloud = _RecordingTaskRepo(initial: <Task>[_task('a'), _task('b')]);
      final tombstones = _MemoryTombstones();
      final repo = HybridTaskRepository(
        hiveRepo: hive,
        supabaseRepo: cloud,
        tombstones: tombstones,
      );

      await repo.deleteTasks(<String>['a']);

      expect(tombstones.ids, <String>{'a'});
      expect(hive.store.map((t) => t.id), <String>['b']);
      expect(cloud.store.map((t) => t.id), <String>['b']);
    });

    test('墓標の書き込みが失敗しても削除自体は続行する', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('a')]);
      final cloud = _RecordingTaskRepo(initial: <Task>[_task('a')]);
      final tombstones = _MemoryTombstones()..failOnMark = true;
      final repo = HybridTaskRepository(
        hiveRepo: hive,
        supabaseRepo: cloud,
        tombstones: tombstones,
      );

      await repo.deleteTasks(<String>['a']);

      expect(hive.store, isEmpty);
      expect(cloud.store, isEmpty);
    });

    test('墓標にある id はクラウドに再登録されていても復元せず、クラウドから掃除する', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('b')]);
      final cloud = _RecordingTaskRepo(
        initial: <Task>[_task('a'), _task('b')], // 'a' は cron/他端末が再登録した想定
      );
      final tombstones = _MemoryTombstones()..ids.add('a');
      final repo = HybridTaskRepository(
        hiveRepo: hive,
        supabaseRepo: cloud,
        tombstones: tombstones,
      );

      final loaded = await repo.loadTasks();

      expect(loaded.map((t) => t.id), <String>['b']);
      expect(cloud.deleteCalls, <List<String>>[
        <String>['a']
      ]);
      expect(cloud.store.map((t) => t.id), <String>['b']);
    });

    test('墓標にないクラウドのみの行は従来どおり取り込む（他端末の新規作成を壊さない）', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('b')]);
      final cloud = _RecordingTaskRepo(
        initial: <Task>[_task('b'), _task('c')],
      );
      final tombstones = _MemoryTombstones();
      final repo = HybridTaskRepository(
        hiveRepo: hive,
        supabaseRepo: cloud,
        tombstones: tombstones,
      );

      final loaded = await repo.loadTasks();

      expect(loaded.map((t) => t.id).toSet(), <String>{'b', 'c'});
      expect(cloud.deleteCalls, isEmpty);
    });

    test('墓標リポジトリ未注入でも従来挙動（後方互換）', () async {
      final hive = _RecordingTaskRepo(initial: <Task>[_task('a')]);
      final cloud = _RecordingTaskRepo(initial: <Task>[_task('a')]);
      final repo = HybridTaskRepository(hiveRepo: hive, supabaseRepo: cloud);

      await repo.deleteTasks(<String>['a']);
      final loaded = await repo.loadTasks();

      expect(loaded, isEmpty);
    });
  });
}
