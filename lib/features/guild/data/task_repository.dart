import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';

class TaskRepository implements ITaskRepository {
  static const String boxName = 'tasksBox';
  static const String _backupBoxName = 'tasksBox_backup';

  // v1.5: Box インスタンスをキャッシュして毎回の openBox を回避
  Box<Task>? _box;
  Box? _backupBox; // v1.3: 保存前のバックアップ用Box

  Future<Box<Task>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Task>(boxName);
    return _box!;
  }

  Future<Box> _getBackupBox() async {
    if (_backupBox != null && _backupBox!.isOpen) return _backupBox!;
    _backupBox = await Hive.openBox(_backupBoxName);
    return _backupBox!;
  }

  @override
  Future<List<Task>> loadTasks() async {
    late Box<Task> box;
    try {
      box = await _getBox();

      // Migration: convert legacy integer-keyed entries to ID-keyed entries.
      // O(1) check: if first key is not int, migration already done
      final needsMigration =
          box.keys.isNotEmpty && box.keys.first is int;
      if (needsMigration) {
        final tasks = box.values.toList();
        await box.clear();
        if (tasks.isNotEmpty) {
          await box.putAll({for (final t in tasks) t.id: t});
        }
        await box.flush();
      }

      // Migration v1.6: 既存の期限を0:00→23:59:59に変換
      final tasks = box.values.toList();
      var needsDeadlineFix = false;
      for (final t in tasks) {
        if (t.deadline != null &&
            t.deadline!.hour == 0 &&
            t.deadline!.minute == 0 &&
            t.deadline!.second == 0) {
          t.deadline = DateTime(
              t.deadline!.year, t.deadline!.month, t.deadline!.day, 23, 59, 59);
          needsDeadlineFix = true;
        }
      }
      if (needsDeadlineFix) {
        await box.putAll({for (final t in tasks) t.id: t});
        await box.flush();
      }

      return tasks;
    } catch (e) {
      // v1.3: 破損時にバックアップから復元を試みる
      debugPrint(
          'TaskRepository: Load failed, attempting backup restore: $e');
      try {
        final backup = await _getBackupBox();
        final keys = backup.get('keys');
        if (keys is List && keys.isNotEmpty) {
          debugPrint(
              'TaskRepository: Restoring ${keys.length} keys from backup');
          box = await _getBox();
          await box.clear();
          for (final key in keys) {
            try {
              await box.put(key, Task(id: key.toString(), title: '(復元: $key)'));
            } catch (_) {}
          }
          await box.flush();
        }
        await backup.clear();
        return box.values.toList();
      } catch (_) {
        debugPrint('TaskRepository: Backup restore failed, returning empty');
        return [];
      }
    }
  }



  /// タスクをIDキーで冪等保存する。
  /// putAll() + deleteAll() の2段階方式。
  /// 空リスト時も box.clear() で正しく永続化する（全タスク削除の反映）。
  /// v1.3: 保存前にバックアップBoxへ退避し、書き込み失敗時の復元を可能にする。
  @override
  Future<void> saveTasks(List<Task> tasks) async {
    final box = await _getBox();
    final backup = await _getBackupBox();

    // v1.3: 保存前に全タスクのキーセットをバックアップ
    try {
      await backup.put('keys', box.keys.toList());
      await backup.put('count', box.length);
    } catch (_) {
      // バックアップ失敗は保存を止めない（復元可能な範囲で進める）
    }

    if (tasks.isEmpty) {
      await box.clear();
      await box.flush();
      // バックアップもクリア
      try { await backup.clear(); } catch (_) {}
      return;
    }

    // 現在のタスクを一括 upsert
    await box.putAll({for (final t in tasks) t.id: t});

    // 削除されたタスクのキーを除去
    final currentIds = tasks.map((t) => t.id).toSet();
    final keysToDelete =
        box.keys.where((k) => !currentIds.contains(k)).toList();
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
    // v1.5: 即座にディスクへ反映（OS kill 耐性の向上）
    await box.flush();

    // 保存成功後、バックアップをクリア
    try { await backup.clear(); } catch (_) {}
  }

  @override
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
    if (_backupBox != null && _backupBox!.isOpen) {
      await _backupBox!.close();
      _backupBox = null;
    }
  }
}
