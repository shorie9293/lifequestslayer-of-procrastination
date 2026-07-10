import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';

/// Supabase上のクエストデータを管理するリポジトリ。
/// [ITaskRepository] インターフェースを実装し、JSONBカラムにTaskを格納する。
class SupabaseTaskRepository implements ITaskRepository {
  final SupabaseClient _client;

  SupabaseTaskRepository(this._client);

  /// 未ログイン時は null。null 安全化により currentUser! の NPE を排除。
  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<Task>> loadTasks() async {
    final userId = _userId;
    if (userId == null) {
      debugPrint('[SupabaseTaskRepo] loadTasks skipped: not signed in');
      return [];
    }
    try {
      final response = await _client
          .from('rpg_tasks')
          .select('data')
          .eq('user_id', userId);

      return response.map<Task>((row) {
        return Task.fromJson(row['data'] as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseTaskRepo] loadTasks failed: $e');
      return [];
    }
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    final userId = _userId;
    if (userId == null) {
      debugPrint('[SupabaseTaskRepo] saveTasks skipped: not signed in');
      return;
    }
    try {
      // ── 削除同期：Supabaseにあって新しいリストにないタスクをDELETE ──
      final existingResponse = await _client
          .from('rpg_tasks')
          .select('id')
          .eq('user_id', userId);
      final existingIds =
          existingResponse.map<String>((r) => r['id'] as String).toSet();
      final newIds = tasks.map((t) => t.id).toSet();
      final deletedIds = existingIds.difference(newIds);
      for (final id in deletedIds) {
        await _client.from('rpg_tasks').delete().eq('id', id);
      }
      if (deletedIds.isNotEmpty) {
        debugPrint(
            '[SupabaseTaskRepo] Deleted ${deletedIds.length} removed tasks');
      }

      // ── upsert残タスク ──
      final rows = tasks.map((task) => {
            'id': task.id,
            'user_id': userId,
            'data': task.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          }).toList();

      if (rows.isNotEmpty) {
        await _client.from('rpg_tasks').upsert(rows);
      }
    } catch (e) {
      debugPrint('[SupabaseTaskRepo] saveTasks failed: $e');
    }
  }

  @override
  Future<void> close() async {
    // SupabaseClient は外部管理のため何もしない
  }
}
