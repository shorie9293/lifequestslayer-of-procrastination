import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_deletion_repository.dart';
import 'package:rpg_todo/core/logging/app_logger.dart';

/// Supabase上のクエストデータを管理するリポジトリ。
/// [ITaskRepository] インターフェースを実装し、JSONBカラムにTaskを格納する。
class SupabaseTaskRepository implements ITaskRepository, ITaskDeletionRepository {
  final SupabaseClient _client;

  SupabaseTaskRepository(this._client);

  /// 未ログイン時は null。null 安全化により currentUser! の NPE を排除。
  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<Task>> loadTasks() async {
    final userId = _userId;
    if (userId == null) {
      appLog.debug('[SupabaseTaskRepo] loadTasks skipped: not signed in');
      return [];
    }
    try {
      final response = await _client
          .from('rpg_tasks')
          .select('data')
          .eq('user_id', userId);

      // 壊れた行が1件あっても全件を失わないよう、行単位で読み取る。
      // （全件throwすると loadTasks が [] を返し、同期がクラウド側の
      //  データを取りこぼしたまま書き戻す事故につながる）
      final tasks = <Task>[];
      for (final row in response) {
        try {
          tasks.add(Task.fromJson(row['data'] as Map<String, dynamic>));
        } catch (e) {
          appLog.warn('[SupabaseTaskRepo] skip malformed row: $e');
        }
      }
      return tasks;
    } catch (e) {
      appLog.warn('[SupabaseTaskRepo] loadTasks failed: $e');
      return [];
    }
  }

  @override
  Future<void> deleteTasks(List<String> ids) async {
    final userId = _userId;
    if (userId == null || ids.isEmpty) return;
    try {
      await _client
          .from('rpg_tasks')
          .delete()
          .eq('user_id', userId)
          .inFilter('id', ids);
    } catch (e) {
      appLog.warn('[SupabaseTaskRepo] deleteTasks failed: $e');
    }
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    final userId = _userId;
    if (userId == null) {
      appLog.debug('[SupabaseTaskRepo] saveTasks skipped: not signed in');
      return;
    }
    try {
      // ── upsert のみ。差分削除は行わない ──
      // 差分削除（クラウドにあって手元にない行を消す）は、手元が古い一覧のまま
      // 保存した瞬間に、他端末や API が入れた行まで消す。削除は deleteTasks() で明示する。
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
      appLog.warn('[SupabaseTaskRepo] saveTasks failed: $e');
    }
  }

  @override
  Future<void> close() async {
    // SupabaseClient は外部管理のため何もしない
  }
}
