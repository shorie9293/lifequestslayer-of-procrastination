import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// Reflection のバックアップ用直列化 codec（純粋 Dart・Hive 非依存）。
///
/// Map 形式:
/// ```json
/// {
///   "id": "...",
///   "taskId": "...",
///   "date": "2026-10-14T00:00:00.000",  // ISO8601
///   "content": "...",
///   "selfDifficulty": 3,
///   "aiDifficulty": 0,  // QuestRank の index（S=0, A=1, B=2）
///   "sentiment": "kaishin" | null
/// }
/// ```
class ReflectionBackupCodec {
  /// Reflection を Map に変換する。
  static Map<String, dynamic> toMap(Reflection r) {
    return {
      'id': r.id,
      'taskId': r.taskId,
      'date': r.date.toIso8601String(),
      'content': r.content,
      'selfDifficulty': r.selfDifficulty,
      'aiDifficulty': r.aiDifficulty.index,
      'sentiment': r.sentiment,
    };
  }

  /// Map を Reflection に復元する。
  ///
  /// 不正・欠落フィールドは FormatException を throw する
  /// （ArgumentError は投げない）。
  static Reflection fromMap(Map<String, dynamic> m) {
    final id = _requireString(m, 'id');
    final taskId = _requireString(m, 'taskId');
    final date = _requireDate(m, 'date');
    final content = _requireString(m, 'content');
    final selfDifficulty = _requireInt(m, 'selfDifficulty');
    final aiDifficulty = _requireQuestRank(m, 'aiDifficulty');
    final sentiment = m['sentiment'] as String?;

    return Reflection(
      id: id,
      taskId: taskId,
      date: date,
      content: content,
      selfDifficulty: selfDifficulty,
      aiDifficulty: aiDifficulty,
      sentiment: sentiment,
    );
  }

  static String _requireString(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is String) return v;
    throw FormatException('Reflection field "$key" must be a String');
  }

  static int _requireInt(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is int) return v;
    throw FormatException('Reflection field "$key" must be an int');
  }

  static DateTime _requireDate(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return d;
    }
    throw FormatException('Reflection field "$key" must be an ISO8601 date');
  }

  static QuestRank _requireQuestRank(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is int && v >= 0 && v < QuestRank.values.length) {
      return QuestRank.values[v];
    }
    throw FormatException('Reflection field "$key" must be a valid QuestRank index');
  }
}
