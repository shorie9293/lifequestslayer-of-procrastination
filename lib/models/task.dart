
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

class QuestRankAdapter extends TypeAdapter<QuestRank> {
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

class Task {
  final String id;
  final String title;
  TaskStatus status;
  bool isCompleted;
  final QuestRank rank;

  Task({
    required this.id,
    required this.title,
    this.status = TaskStatus.inGuild,
    this.isCompleted = false,
    this.rank = QuestRank.B,
  });
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
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.write(obj.id);
    writer.write(obj.title);
    writer.write(obj.status);
    writer.write(obj.isCompleted);
    writer.write(obj.rank);
  }
}
