
import 'package:hive/hive.dart';

enum TaskStatus { inGuild, active }

class TaskStatusAdapter extends TypeAdapter<TaskStatus> {
  @override
  final int typeId = 1;

  @override
  TaskStatus read(BinaryReader reader) {
    return TaskStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, TaskStatus obj) {
    writer.writeByte(obj.index);
  }
}

enum QuestRank { S, A, B }


class QuestionRankAdapter extends TypeAdapter<QuestRank> { // Renaming to avoid conflict if any, but sticking to existing name
  @override
  final int typeId = 2;

  @override
  QuestRank read(BinaryReader reader) {
    return QuestRank.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, QuestRank obj) {
    writer.writeByte(obj.index);
  }
}

enum RepeatInterval {
  none,
  daily,
  weekly,
}

class RepeatIntervalAdapter extends TypeAdapter<RepeatInterval> {
  @override
  final int typeId = 5;

  @override
  RepeatInterval read(BinaryReader reader) {
    return RepeatInterval.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, RepeatInterval obj) {
    writer.writeByte(obj.index);
  }
}

class SubTask {
  String title;
  bool isCompleted;

  SubTask({
    required this.title,
    this.isCompleted = false,
  });
}

class SubTaskAdapter extends TypeAdapter<SubTask> {
  @override
  final int typeId = 6;

  @override
  SubTask read(BinaryReader reader) {
    return SubTask(
      title: reader.read(),
      isCompleted: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, SubTask obj) {
    writer.write(obj.title);
    writer.write(obj.isCompleted);
  }
}

class Task {
  final String id;
  final String title;
  TaskStatus status;
  bool isCompleted;
  final QuestRank rank;
  RepeatInterval repeatInterval;
  List<int> repeatWeekdays; // 1=Mon, ..., 7=Sun
  DateTime? lastCompletedAt;
  List<SubTask> subTasks;

  Task({
    required this.id,
    required this.title,
    this.status = TaskStatus.inGuild,
    this.isCompleted = false,
    this.rank = QuestRank.B,
    this.repeatInterval = RepeatInterval.none,
    List<int>? repeatWeekdays,
    this.lastCompletedAt,
    List<SubTask>? subTasks,
  }) : subTasks = subTasks ?? [], repeatWeekdays = repeatWeekdays ?? [];
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    return Task(
      id: reader.read(),
      title: reader.read(),
      status: reader.read(), // Hive handles nested adapters automatically
      isCompleted: reader.read(),
      rank: reader.read(),
      repeatInterval: reader.read(),
      repeatWeekdays: (reader.read() as List?)?.cast<int>() ?? [],
      lastCompletedAt: reader.read(), // DateTime adapter is built-in or primitive? DateTime is supported by Hive generally
      subTasks: (reader.read() as List).cast<SubTask>(),
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.write(obj.id);
    writer.write(obj.title);
    writer.write(obj.status);
    writer.write(obj.isCompleted);
    writer.write(obj.rank);
    writer.write(obj.repeatInterval);
    writer.write(obj.repeatWeekdays);
    writer.write(obj.lastCompletedAt);
    writer.write(obj.subTasks);
  }
}
