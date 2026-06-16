import 'package:rpg_todo/domain/models/task.dart';

/// T11: Mystic Lv15 俯瞰の魔眼 — Overview view data services
class OverviewService {
  /// Tasks grouped by deadline date string (YYYY-MM-DD).
  /// Tasks without a deadline go under "No deadline".
  Map<String, List<Task>> groupTasksByDeadline(List<Task> tasks) {
    if (tasks.isEmpty) return {};
    final grouped = <String, List<Task>>{};
    for (final task in tasks) {
      final key = task.deadline != null
          ? '${task.deadline!.year}-${task.deadline!.month.toString().padLeft(2, '0')}-${task.deadline!.day.toString().padLeft(2, '0')}'
          : 'No deadline';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(task);
    }
    return grouped;
  }

  /// Tasks grouped by [TaskStatus].
  Map<TaskStatus, List<Task>> groupTasksByStatus(List<Task> tasks) {
    if (tasks.isEmpty) return {};
    final grouped = <TaskStatus, List<Task>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.status, () => []);
      grouped[task.status]!.add(task);
    }
    return grouped;
  }
}
