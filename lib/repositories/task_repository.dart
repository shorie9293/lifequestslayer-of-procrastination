import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';

class TaskRepository {
  static const String boxName = 'tasksBox';

  // v1.5: Box インスタンスをキャッシュして毎回の openBox を回避
  Box<Task>? _box;

  Future<Box<Task>> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<Task>(boxName);
    return _box!;
  }

  Future<List<Task>> loadTasks() async {
    try {
      final box = await _getBox();

      // Migration: convert legacy integer-keyed entries to ID-keyed entries.
      // Old code used box.addAll() which assigns auto-increment integer keys.
      final needsMigration = box.keys.any((k) => k is int);
      if (needsMigration) {
        final tasks = box.values.toList();
        await box.clear();
        if (tasks.isNotEmpty) {
          await box.putAll({for (final t in tasks) t.id: t});
        }
        // v1.5: マイグレーション結果を即座にディスクへ反映
        await box.flush();
      }

      return box.values.toList();
    } catch (e) {
      // v1.6: 破損または旧形式の Box を自動修復
      debugPrint('TaskRepository: Load failed (corrupted/incompatible data), deleting box: $e');
      await _closeAndDeleteBox();
      return [];
    }
  }

  /// 破損 Box を削除（次回アクセス時に自動再作成される）
  Future<void> _closeAndDeleteBox() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
      }
      _box = null;
      await Hive.deleteBoxFromDisk(boxName);
    } catch (_) {
      // Best effort
    }
  }

  /// タスクをIDキーで冪等保存する。
  /// putAll() + deleteAll() の2段階方式。
  /// 空リスト時も box.clear() で正しく永続化する（全タスク削除の反映）。
  Future<void> saveTasks(List<Task> tasks) async {
    final box = await _getBox();

    if (tasks.isEmpty) {
      await box.clear();
      // v1.5: 即座にディスクへ反映
      await box.flush();
      return;
    }

    // 現在のタスクを一括 upsert
    await box.putAll({for (final t in tasks) t.id: t});

    // 削除されたタスクのキーを除去
    final currentIds = tasks.map((t) => t.id).toSet();
    final keysToDelete = box.keys.where((k) => !currentIds.contains(k)).toList();
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
    // v1.5: 即座にディスクへ反映（OS kill 耐性の向上）
    await box.flush();
  }

  // v1.5: リソース解放（dispose 時に呼ぶ）
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}
