import 'package:rpg_todo/domain/models/task.dart';

/// タスクデータ永続化の抽象インターフェース
/// 試練時はMockを注入することで、Hiveに依存しないWidgetテストが可能になる
abstract class ITaskRepository {
  Future<List<Task>> loadTasks();
  Future<void> saveTasks(List<Task> tasks);
  Future<void> close();
}
