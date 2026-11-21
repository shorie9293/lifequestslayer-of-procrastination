import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_deletion_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_tombstone_repository.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';

/// Hive（ローカル）と Supabase（クラウド）の二重書き込みハイブリッドリポジトリ。
/// Hiveをプライマリ、Supabaseをセカンダリとする。
/// - 読み込み: Hiveから読み込み → 非同期でSupabaseとマージ（新しい方を優先）
/// - 書き込み: Hiveに保存 → 成功後、非同期でSupabaseにも保存（失敗は無視）
///
/// 削除は「墓標（tombstone）」を先に書く。行を消すだけでは、cron・他端末・API が
/// 同じ id を再登録したときにマージが「クラウドにのみ存在」と判断して復元してしまう。
class HybridTaskRepository implements ITaskRepository, ITaskDeletionRepository {
  final ITaskRepository _hiveRepo;
  final ITaskRepository _supabaseRepo;
  final ITaskTombstoneRepository? _tombstones;

  HybridTaskRepository({
    required ITaskRepository hiveRepo,
    required ITaskRepository supabaseRepo,
    ITaskTombstoneRepository? tombstones,
  })  : _hiveRepo = hiveRepo,
        _supabaseRepo = supabaseRepo,
        _tombstones = tombstones;

  @override
  Future<List<Task>> loadTasks() async {
    // プライマリ: Hiveから読み込み
    final tasks = await _hiveRepo.loadTasks();

    // セカンダリ: Supabaseと同期（awaitで確実に完了を待つ）
    try {
      await _syncFromSupabase(tasks).timeout(const Duration(seconds: 5));
    } catch (e) {
      appLog.warn('[HybridTaskRepo] Sync timeout, using local data: $e');
    }

    // マージ後の最新データをHiveから再読み込み
    return await _hiveRepo.loadTasks();
  }

  /// last-write-wins で Supabase とローカルを統合する。
  /// - ローカルにのみ存在 → ローカルを保持し、クラウドへ push
  /// - クラウドにのみ存在 → クラウドを採用しローカルへ追加
  /// - 両方に存在 → updatedAt が新しい方を採用（同時ならローカル優先）。
  ///   ローカルが新しければクラウドへ push、クラウドが新しければローカルへ書き込み
  ///
  /// ただし **墓標（削除済み）の id は採用しない**。クラウド側に残っていれば
  /// クラウドからも掃除する（cron・他端末・API による再登録を無効化する）。
  Future<void> _syncFromSupabase(List<Task> localTasks) async {
    try {
      final tombstones = await _loadTombstones();
      final remoteTasks = await _supabaseRepo.loadTasks();

      final merged = <String, Task>{};
      final localWins = <String, Task>{};
      final resurrected = <String>[];

      // ローカルのタスクをマップに投入（墓標の id は捨てる）
      for (final t in localTasks) {
        if (tombstones.contains(t.id)) continue;
        merged[t.id] = t;
      }

      for (final remote in remoteTasks) {
        if (tombstones.contains(remote.id)) {
          // 削除済みなのにクラウドに在る＝再登録された分。採用せず掃除する。
          resurrected.add(remote.id);
          continue;
        }
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
      if (localWins.isNotEmpty || _hasLocalOnly(mergedList, remoteTasks)) {
        await _supabaseRepo.saveTasks(mergedList);
      }

      // 復活した行をクラウドから消す（失敗しても次回の起動で再試行される）
      if (resurrected.isNotEmpty) {
        await _deleteFromCloud(resurrected);
      }

      appLog.debug(
          '[HybridTaskRepo] Synced: local=${localTasks.length} → merged=${mergedList.length}, localWins=${localWins.length}, purged=${resurrected.length}');
    } catch (e) {
      appLog.warn('[HybridTaskRepo] Sync failed (offline): $e');
    }
  }

  /// 墓標を読む（未注入・失敗時は空＝従来挙動）。
  Future<Set<String>> _loadTombstones() async {
    final repo = _tombstones;
    if (repo == null) return <String>{};
    try {
      return await repo.loadTombstones();
    } catch (e) {
      appLog.warn('[HybridTaskRepo] loadTombstones failed: $e');
      return <String>{};
    }
  }

  /// クラウド側の行を削除する。
  Future<void> _deleteFromCloud(List<String> ids) async {
    final cloud = _supabaseRepo;
    if (cloud is! ITaskDeletionRepository) return;
    try {
      await (cloud as ITaskDeletionRepository).deleteTasks(ids);
    } catch (e) {
      appLog.warn('[HybridTaskRepo] Supabase purge failed: $e');
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
      appLog.warn('[HybridTaskRepo] Supabase save failed (offline): $e');
    });
  }

  @override
  Future<void> deleteTasks(List<String> ids) async {
    if (ids.isEmpty) return;

    // 1) 先に墓標を書く（行を消すだけでは再登録で復活する）
    final tomb = _tombstones;
    if (tomb != null) {
      try {
        await tomb.markDeleted(ids, source: 'app_delete');
      } catch (e) {
        appLog.warn('[HybridTaskRepo] markDeleted failed: $e');
      }
    }

    // 2) ローカル（Hive）から削除
    final hive = _hiveRepo;
    if (hive is ITaskDeletionRepository) {
      await (hive as ITaskDeletionRepository).deleteTasks(ids);
    }

    // 3) クラウドから削除（失敗しても墓標が守る＝次回同期で掃除される）
    await _deleteFromCloud(ids);
  }

  @override
  Future<void> close() async {
    await _hiveRepo.close();
    await _supabaseRepo.close();
  }
}
