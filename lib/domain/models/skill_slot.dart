import 'player.dart';

/// 装備中のスキルを表す値オブジェクト。
class EquippedSkill {
  final JobSkill skill;

  const EquippedSkill({required this.skill});

  Map<String, dynamic> toJson() => {
        'skill': skill.index,
      };

  factory EquippedSkill.fromJson(Map<String, dynamic> json) {
    return EquippedSkill(
      skill: JobSkill.values[json['skill'] as int],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquippedSkill &&
          runtimeType == other.runtimeType &&
          skill == other.skill;

  @override
  int get hashCode => skill.hashCode;
}

/// 魔法使いのプロジェクト管理用グループ。
class ProjectGroup {
  String name;
  List<String> taskIds;
  List<String> tags;

  ProjectGroup({
    required this.name,
    List<String>? taskIds,
    List<String>? tags,
  })  : taskIds = taskIds ?? [],
        tags = tags ?? [];

  void addTask(String taskId) {
    if (!taskIds.contains(taskId)) {
      taskIds.add(taskId);
    }
  }

  void removeTask(String taskId) {
    taskIds.remove(taskId);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'taskIds': taskIds,
        'tags': tags,
      };

  factory ProjectGroup.fromJson(Map<String, dynamic> json) {
    return ProjectGroup(
      name: json['name'] as String,
      taskIds: (json['taskIds'] as List?)?.cast<String>(),
      tags: (json['tags'] as List?)?.cast<String>(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectGroup &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          _listEquals(taskIds, other.taskIds) &&
          _listEquals(tags, other.tags);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(taskIds), Object.hashAll(tags));
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
