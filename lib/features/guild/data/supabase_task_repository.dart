import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';

/// Supabase上のクエストデータを管理するリポジトリ。
/// [ITaskRepository] インターフェースを実装し、JSONBカラムにTaskを格納する。
class SupabaseTaskRepository implements ITaskRepository {
  final SupabaseClient _client;

  SupabaseTaskRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Task>> loadTasks() async {
    try {
      final response = await _client
          .from('rpg_tasks')
          .select('data')
          .eq('user_id', _userId);

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
    try {
      final rows = tasks.map((task) => {
            'id': task.id,
            'user_id': _userId,
            'data': task.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          }).toList();

      await _client.from('rpg_tasks').upsert(rows);
    } catch (e) {
      debugPrint('[SupabaseTaskRepo] saveTasks failed: $e');
    }
  }

  @override
  Future<void> close() async {
    // SupabaseClient は外部管理のため何もしない
  }
}
