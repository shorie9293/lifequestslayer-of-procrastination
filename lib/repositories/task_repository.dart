import 'package:hive/hive.dart';
import '../models/task.dart';

class TaskRepository {
  static const String boxName = 'tasksBox';

  Future<List<Task>> loadTasks() async {
    print("TaskRepository: Loading tasks...");
    final box = await Hive.openBox<Task>(boxName);
    print("TaskRepository: Loaded ${box.length} tasks.");
    return box.values.toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    print("TaskRepository: Saving ${tasks.length} tasks...");
    final box = await Hive.openBox<Task>(boxName);
    await box.clear();
    await box.addAll(tasks);
    print("TaskRepository: Tasks saved.");
  }

  Future<void> updateTask(Task task) async {
    // Ideally we would update just one, but Hive List storage relies on rewriting or handling keys carefully.
    // Since we store as list in implementation_plan (and current code), re-saving all or finding by key.
    // The current implementation in GameState saves ALL on every change. 
    // Optimization: If we stored with Keys = IDs, we could update one.
    // For now, let's keep the pattern but allow improvements later.
    // Actually, box.addAll appends? No, explicit clear is safer for list integrity if index matters.
    // But let's support saving all for now to match current behavior safely.
  }
}
