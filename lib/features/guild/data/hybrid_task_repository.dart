import 'package:flutter/foundation.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';

/// Hive（ローカル）と Supabase（クラウド）の二重書き込みハイブリッドリポジトリ。
/// Hiveをプライマリ、Supabaseをセカンダリとする。
/// - 読み込み: Hiveから読み込み → 非同期でSupabaseとマージ（新しい方を優先）
/// - 書き込み: Hiveに保存 → 成功後、非同期でSupabaseにも保存（失敗は無視）
class HybridTaskRepository implements ITaskRepository {
  final ITaskRepository _hiveRepo;
  final ITaskRepository _supabaseRepo;

  HybridTaskRepository({
    required ITaskRepository hiveRepo,
    required ITaskRepository supabaseRepo,
  })  : _hiveRepo = hiveRepo,
        _supabaseRepo = supabaseRepo;

  @override
  Future<List<Task>> loadTasks() async {
    // プライマリ: Hiveから読み込み
    final tasks = await _hiveRepo.loadTasks();

    // セカンダリ: Supabaseと同期（awaitで確実に完了を待つ）
    try {
      await _syncFromSupabase(tasks).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[HybridTaskRepo] Sync timeout, using local data: $e');
    }

    // マージ後の最新データをHiveから再読み込み
    return await _hiveRepo.loadTasks();
  }

  /// Supabaseからデータを読み込み、Hiveのデータとマージする。
  /// 新しい方を優先（updated_at比較はTaskにないので、Supabaseのデータで上書き方針）。
  Future<void> _syncFromSupabase(List<Task> localTasks) async {
    try {
      final remoteTasks = await _supabaseRepo.loadTasks();
      if (remoteTasks.isEmpty) return;

      // リモートのタスクをローカルにマージ
      final merged = Map<String, Task>.fromEntries(
        localTasks.map((t) => MapEntry(t.id, t)),
      );

      for (final remote in remoteTasks) {
        // リモートにあってローカルにない → 追加
        // 両方にある → リモートを優先
        merged[remote.id] = remote;
      }

      final mergedList = merged.values.toList();
      await _hiveRepo.saveTasks(mergedList);
      debugPrint(
          '[HybridTaskRepo] Synced: local=${localTasks.length} → merged=${mergedList.length}');
    } catch (e) {
      debugPrint('[HybridTaskRepo] Sync failed (offline): $e');
    }
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    // プライマリ: Hiveに即時保存
    await _hiveRepo.saveTasks(tasks);

    // セカンダリ: Supabaseに非同期保存（失敗は無視）
    _supabaseRepo.saveTasks(tasks).catchError((e) {
      debugPrint('[HybridTaskRepo] Supabase save failed (offline): $e');
    });
  }

  @override
  Future<void> close() async {
    await _hiveRepo.close();
    await _supabaseRepo.close();
  }
}
