import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/domain/repositories/i_task_tombstone_repository.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';

/// Supabase 上の `rpg_task_tombstones` を読み書きする実装。
///
/// 未ログイン時は何もしない（オフラインでも削除自体は成功させる）。
/// 時刻は **UTC** で書く（端末のローカル時刻を UTC 列へ入れると +9h ずれる）。
class SupabaseTaskTombstoneRepository implements ITaskTombstoneRepository {
  SupabaseTaskTombstoneRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'rpg_task_tombstones';

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<void> markDeleted(Iterable<String> taskIds, {String? source}) async {
    final userId = _userId;
    final ids = taskIds.toList(growable: false);
    if (userId == null || ids.isEmpty) return;
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = ids
          .map((id) => <String, dynamic>{
                'user_id': userId,
                'task_id': id,
                'deleted_at': now,
                'source': source ?? 'app',
              })
          .toList();
      await _client.from(_table).upsert(rows);
    } catch (e) {
      // 墓標が書けなくても削除は止めない（次回の削除・同期で再試行される）
      appLog.warn('[TombstoneRepo] markDeleted failed: $e');
    }
  }

  @override
  Future<Set<String>> loadTombstones() async {
    final userId = _userId;
    if (userId == null) return <String>{};
    try {
      final response =
          await _client.from(_table).select('task_id').eq('user_id', userId);
      return response
          .map((row) => row['task_id'] as String)
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      appLog.warn('[TombstoneRepo] loadTombstones failed: $e');
      return <String>{};
    }
  }

  @override
  Future<void> clear(Iterable<String> taskIds) async {
    final userId = _userId;
    final ids = taskIds.toList(growable: false);
    if (userId == null || ids.isEmpty) return;
    try {
      await _client
          .from(_table)
          .delete()
          .eq('user_id', userId)
          .inFilter('task_id', ids);
    } catch (e) {
      appLog.warn('[TombstoneRepo] clear failed: $e');
    }
  }
}
