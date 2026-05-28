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

class QuestionRankAdapter extends TypeAdapter<QuestRank> {
  @override
  final int typeId = 2;

  @override
  QuestRank read(BinaryReader reader) {
    final ordinal = reader.readByte();
    // 旧Cランク(序数3) → Bランクに安全移行
    if (ordinal >= QuestRank.values.length) {
      return QuestRank.B;
    }
    return QuestRank.values[ordinal];
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
  String title;
  TaskStatus status;
  bool isCompleted;
  QuestRank rank;
  RepeatInterval repeatInterval;
  List<int> repeatWeekdays; // 1=Mon, ..., 7=Sun
  DateTime? lastCompletedAt;
  List<SubTask> subTasks;
  int? targetTimeMinutes; // 見積もり時間（分）
  DateTime? activeAt; // タスク開始日時（アクティブ化した日時）
  DateTime? deadline; // 完成期限
  int? repeatAfterDays; // Cleric Lv1 後追いの祈り: N日後に再活性化
  List<String> tags; // wizardTags: 札（タグ）

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
    this.targetTimeMinutes,
    this.activeAt,
    this.deadline,
    this.repeatAfterDays,
    List<String>? tags,
  })  : subTasks = subTasks ?? [],
        repeatWeekdays = repeatWeekdays ?? [],
        tags = tags ?? [];

  /// 札を追加（wizardTags: 重複防止）
  void addTag(String tag) {
    if (!tags.contains(tag)) {
      tags.add(tag);
    }
  }

  /// 札を削除
  void removeTag(String tag) {
    tags.remove(tag);
  }

  /// 札を持っているか
  bool hasTag(String tag) => tags.contains(tag);

  /// repeatAfterDays が設定され、lastCompletedAt から repeatAfterDays 日経過したか判定。
  bool shouldReactivate() {
    if (repeatAfterDays == null || lastCompletedAt == null) return false;
    final reactivateDate = lastCompletedAt!.add(Duration(days: repeatAfterDays!));
    return DateTime.now().isAfter(reactivateDate) ||
        DateTime.now().day == reactivateDate.day &&
            DateTime.now().month == reactivateDate.month &&
            DateTime.now().year == reactivateDate.year;
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final task = Task(
      id: reader.read(),
      title: reader.read(),
      status: reader.read(), // Hive handles nested adapters automatically
      isCompleted: reader.read(),
      rank: reader.read(),
      repeatInterval: reader.read(),
      repeatWeekdays: (reader.read() as List?)?.cast<int>() ?? [],
      lastCompletedAt: reader
          .read(), // DateTime adapter is built-in or primitive? DateTime is supported by Hive generally
      subTasks: (reader.read() as List?)?.cast<SubTask>() ?? [],
    );
    try {
      task.targetTimeMinutes = reader.read();
      task.activeAt = reader.read();
      task.deadline = reader.read();
      task.repeatAfterDays = reader.read();
      task.tags = (reader.read() as List?)?.cast<String>() ?? [];
    } catch (e) {
      // 過去のデータを読み込んだ場合のフォールバック
    }
    return task;
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
    writer.write(obj.targetTimeMinutes);
    writer.write(obj.activeAt);
    writer.write(obj.deadline);
    writer.write(obj.repeatAfterDays);
    writer.write(obj.tags);
  }
}
