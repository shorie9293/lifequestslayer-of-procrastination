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

  /// last-write-wins で Supabase とローカルを統合する。
  /// - ローカルにのみ存在 → ローカルを保持し、クラウドへ push
  /// - クラウドにのみ存在 → クラウドを採用しローカルへ追加
  /// - 両方に存在 → updatedAt が新しい方を採用（同時ならローカル優先）。
  ///   ローカルが新しければクラウドへ push、クラウドが新しければローカルへ書き込み
  Future<void> _syncFromSupabase(List<Task> localTasks) async {
    try {
      final remoteTasks = await _supabaseRepo.loadTasks();

      final merged = <String, Task>{};
      final localWins = <String, Task>{};

      // ローカルのタスクをマップに投入
      for (final t in localTasks) {
        merged[t.id] = t;
      }

      for (final remote in remoteTasks) {
        final local = merged[remote.id];
        if (local == null) {
          // クラウドのみ → クラウドを採用（ローカルへ追加）
          merged[remote.id] = remote;
        } else {
          // 両方 → last-write-wins。同時はローカル優先。
          final localTs = local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final remoteTs =
              remote.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (remoteTs.isAfter(localTs)) {
            merged[remote.id] = remote; // クラウドが新しい → クラウド採用
          } else {
            localWins[remote.id] = local; // ローカルが新しい/同時 → ローカル保持
          }
        }
      }

      final mergedList = merged.values.toList();
      await _hiveRepo.saveTasks(mergedList);

      // ローカル優先タスク or ローカルのみタスクをクラウドへ push
      // （saveTasks は削除同期 + upsert を行うため、マージ済みリスト全体を渡してよい）
      if (localWins.isNotEmpty || _hasLocalOnly(localTasks, remoteTasks)) {
        await _supabaseRepo.saveTasks(mergedList);
      }
      debugPrint(
          '[HybridTaskRepo] Synced: local=${localTasks.length} → merged=${mergedList.length}, localWins=${localWins.length}');
    } catch (e) {
      debugPrint('[HybridTaskRepo] Sync failed (offline): $e');
    }
  }

  /// ローカルにのみ存在する（クラウドにない）タスクがあるか
  bool _hasLocalOnly(List<Task> localTasks, List<Task> remoteTasks) {
    final remoteIds = remoteTasks.map((t) => t.id).toSet();
    return localTasks.any((t) => !remoteIds.contains(t.id));
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    // ローカル保存のタイムスタンプを付与（last-write-wins 判定用）
    final now = DateTime.now();
    for (final t in tasks) {
      t.updatedAt = now;
    }

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
