
enum TaskStatus { inGuild, active }

enum QuestRank { S, A, B }

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
