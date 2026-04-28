import 'package:hive/hive.dart';
import '../models/task.dart';

class TaskRepository {
  static const String boxName = 'tasksBox';

  Future<List<Task>> loadTasks() async {
    final box = await Hive.openBox<Task>(boxName);

    // Migration: convert legacy integer-keyed entries to ID-keyed entries.
    // Old code used box.addAll() which assigns auto-increment integer keys.
    final needsMigration = box.keys.any((k) => k is int);
    if (needsMigration) {
      final tasks = box.values.toList();
      await box.clear();
      if (tasks.isNotEmpty) {
        await box.putAll({for (final t in tasks) t.id: t});
      }
    }

    return box.values.toList();
  }

  /// タスクをIDキーで冪等保存する。
  /// clear()+addAll() は保存途中にアプリが終了するとデータが全消失するため、
  /// putAll() + deleteAll() の2段階に変更。putAll は失敗しても既存データを破壊しない。
  Future<void> saveTasks(List<Task> tasks) async {
    final box = await Hive.openBox<Task>(boxName);

    if (tasks.isEmpty) return;

    // 現在のタスクを一括 upsert
    await box.putAll({for (final t in tasks) t.id: t});

    // 削除されたタスクのキーを除去
    final currentIds = tasks.map((t) => t.id).toSet();
    final keysToDelete = box.keys.where((k) => !currentIds.contains(k)).toList();
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }
}
