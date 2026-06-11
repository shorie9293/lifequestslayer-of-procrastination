import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// 討伐後の振り返り（内省）エントリ。
///
/// 討伐完了時にユーザーが入力する「学び」の記録と、
/// 自己評価難易度とAI推定難易度の比較を保持する。
@HiveType(typeId: 7)
class Reflection extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String taskId;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String content;

  /// ユーザー自己評価難易度（1=易しい, 5=非常に難しい）
  @HiveField(4)
  final int selfDifficulty;

  /// AI推定難易度ランク
  @HiveField(5)
  final QuestRank aiDifficulty;

  Reflection({
    required this.id,
    required this.taskId,
    required this.date,
    required this.content,
    required this.selfDifficulty,
    required this.aiDifficulty,
  });

  /// AI難易度を1-5の数値に変換（比較用）
  /// S=5, A=3, B=1
  int get aiDifficultyValue {
    switch (aiDifficulty) {
      case QuestRank.S:
        return 5;
      case QuestRank.A:
        return 3;
      case QuestRank.B:
        return 1;
    }
  }
}

/// Hive Adapter for Reflection
class ReflectionAdapter extends TypeAdapter<Reflection> {
  @override
  final int typeId = 7;

  @override
  Reflection read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      final fieldIndex = reader.readByte();
      switch (fieldIndex) {
        case 0:
          fields[0] = reader.readString();
          break;
        case 1:
          fields[1] = reader.readString();
          break;
        case 2:
          fields[2] = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
          break;
        case 3:
          fields[3] = reader.readString();
          break;
        case 4:
          fields[4] = reader.readInt();
          break;
        case 5:
          fields[5] = QuestRank.values[reader.readByte()];
          break;
        default:
          // 未知のフィールドはスキップ（前方互換性）
          reader.readByte();
      }
    }
    return Reflection(
      id: fields[0] as String,
      taskId: fields[1] as String,
      date: fields[2] as DateTime,
      content: fields[3] as String,
      selfDifficulty: fields[4] as int,
      aiDifficulty: fields[5] as QuestRank,
    );
  }

  @override
  void write(BinaryWriter writer, Reflection obj) {
    writer.writeByte(6); // フィールド数
    writer.writeByte(0);
    writer.writeString(obj.id);
    writer.writeByte(1);
    writer.writeString(obj.taskId);
    writer.writeByte(2);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeByte(3);
    writer.writeString(obj.content);
    writer.writeByte(4);
    writer.writeInt(obj.selfDifficulty);
    writer.writeByte(5);
    writer.writeByte(obj.aiDifficulty.index);
  }
}
