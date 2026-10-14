import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/reflection_backup_codec.dart';

void main() {
  Reflection makeReflection({
    String? sentiment,
    QuestRank rank = QuestRank.A,
  }) {
    return Reflection(
      id: 'ref-1',
      taskId: 'task-1',
      date: DateTime(2026, 10, 14, 9, 30),
      content: '今日の学び',
      selfDifficulty: 3,
      aiDifficulty: rank,
      sentiment: sentiment,
    );
  }

  group('ReflectionBackupCodec - toMap / fromMap round-trip', () {
    test('all fields survive round-trip', () {
      final r = makeReflection(sentiment: 'kaishin', rank: QuestRank.S);
      final map = ReflectionBackupCodec.toMap(r);
      final restored = ReflectionBackupCodec.fromMap(map);

      expect(restored.id, r.id);
      expect(restored.taskId, r.taskId);
      expect(restored.date, r.date);
      expect(restored.content, r.content);
      expect(restored.selfDifficulty, r.selfDifficulty);
      expect(restored.aiDifficulty, r.aiDifficulty);
      expect(restored.sentiment, r.sentiment);
    });

    test('round-trip with null sentiment', () {
      final r = makeReflection(sentiment: null);
      final map = ReflectionBackupCodec.toMap(r);
      expect(map['sentiment'], isNull);
      final restored = ReflectionBackupCodec.fromMap(map);
      expect(restored.sentiment, isNull);
    });

    test('round-trip with non-null sentiment (imashime)', () {
      final r = makeReflection(sentiment: 'imashime');
      final restored = ReflectionBackupCodec.fromMap(
          ReflectionBackupCodec.toMap(r));
      expect(restored.sentiment, 'imashime');
    });

    test('aiDifficulty is stored as QuestRank index', () {
      expect(
          ReflectionBackupCodec.toMap(makeReflection(rank: QuestRank.S))['aiDifficulty'],
          QuestRank.S.index);
      expect(
          ReflectionBackupCodec.toMap(makeReflection(rank: QuestRank.A))['aiDifficulty'],
          QuestRank.A.index);
      expect(
          ReflectionBackupCodec.toMap(makeReflection(rank: QuestRank.B))['aiDifficulty'],
          QuestRank.B.index);
    });

    test('date is serialized as ISO8601 string', () {
      final map = ReflectionBackupCodec.toMap(makeReflection());
      expect(map['date'], isA<String>());
      expect(map['date'], '2026-10-14T09:30:00.000');
    });

    test('fromMap restores QuestRank from index', () {
      final map = ReflectionBackupCodec.toMap(makeReflection(rank: QuestRank.B));
      map['aiDifficulty'] = QuestRank.B.index;
      expect(ReflectionBackupCodec.fromMap(map).aiDifficulty, QuestRank.B);
    });
  });

  group('ReflectionBackupCodec - invalid maps throw FormatException', () {
    test('missing fields throw FormatException', () {
      final base = ReflectionBackupCodec.toMap(makeReflection());
      for (final key in ['id', 'taskId', 'date', 'content', 'selfDifficulty', 'aiDifficulty']) {
        final broken = Map<String, dynamic>.from(base)..remove(key);
        expect(
          () => ReflectionBackupCodec.fromMap(broken),
          throwsFormatException,
          reason: '欠落キー $key で FormatException が expected',
        );
      }
    });

    test('wrong field types throw FormatException', () {
      final base = ReflectionBackupCodec.toMap(makeReflection());
      expect(
        () => ReflectionBackupCodec.fromMap(
            Map<String, dynamic>.from(base)..['selfDifficulty'] = 'three'),
        throwsFormatException,
      );
      expect(
        () => ReflectionBackupCodec.fromMap(
            Map<String, dynamic>.from(base)..['aiDifficulty'] = 'S'),
        throwsFormatException,
      );
      expect(
        () => ReflectionBackupCodec.fromMap(
            Map<String, dynamic>.from(base)..['date'] = 12345),
        throwsFormatException,
      );
      expect(
        () => ReflectionBackupCodec.fromMap(
            Map<String, dynamic>.from(base)..['id'] = 42),
        throwsFormatException,
      );
    });

    test('out-of-range aiDifficulty index throws FormatException', () {
      final base = ReflectionBackupCodec.toMap(makeReflection());
      expect(
        () => ReflectionBackupCodec.fromMap(
            Map<String, dynamic>.from(base)..['aiDifficulty'] = 99),
        throwsFormatException,
      );
      expect(
        () => ReflectionBackupCodec.fromMap(
            Map<String, dynamic>.from(base)..['aiDifficulty'] = -1),
        throwsFormatException,
      );
    });

    test('unparsable date throws FormatException', () {
      final base = ReflectionBackupCodec.toMap(makeReflection());
      expect(
        () => ReflectionBackupCodec.fromMap(
            Map<String, dynamic>.from(base)..['date'] = 'not-a-date'),
        throwsFormatException,
      );
    });
  });
}
