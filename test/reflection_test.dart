import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';

void main() {
  late String tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('hive_test_').path;
    Hive.init(tempDir);
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ReflectionAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    Directory(tempDir).deleteSync(recursive: true);
  });

  group('Reflection model', () {
    test('creates with all fields', () {
      final now = DateTime.now();
      final reflection = Reflection(
        id: 'test-id-1',
        taskId: 'task-1',
        date: now,
        content: '小さく始めるのが大事',
        selfDifficulty: 3,
        aiDifficulty: QuestRank.A,
      );

      expect(reflection.id, 'test-id-1');
      expect(reflection.taskId, 'task-1');
      expect(reflection.date, now);
      expect(reflection.content, '小さく始めるのが大事');
      expect(reflection.selfDifficulty, 3);
      expect(reflection.aiDifficulty, QuestRank.A);
    });

    test('aiDifficultyValue maps correctly', () {
      final sRank = Reflection(
        id: '1', taskId: 't1', date: DateTime.now(),
        content: '', selfDifficulty: 5, aiDifficulty: QuestRank.S,
      );
      final aRank = Reflection(
        id: '2', taskId: 't2', date: DateTime.now(),
        content: '', selfDifficulty: 3, aiDifficulty: QuestRank.A,
      );
      final bRank = Reflection(
        id: '3', taskId: 't3', date: DateTime.now(),
        content: '', selfDifficulty: 1, aiDifficulty: QuestRank.B,
      );

      expect(sRank.aiDifficultyValue, 5);
      expect(aRank.aiDifficultyValue, 3);
      expect(bRank.aiDifficultyValue, 1);
    });

    test('selfDifficulty stays within 1-5', () {
      final reflection = Reflection(
        id: '1', taskId: 't1', date: DateTime.now(),
        content: '', selfDifficulty: 3, aiDifficulty: QuestRank.B,
      );
      expect(reflection.selfDifficulty, greaterThanOrEqualTo(1));
      expect(reflection.selfDifficulty, lessThanOrEqualTo(5));
    });
  });

  group('Reflection Hive persistence', () {
    test('roundtrip through Hive box', () async {
      final box = await Hive.openBox<Reflection>('test_reflections');
      final reflection = Reflection(
        id: 'r1',
        taskId: 't99',
        date: DateTime(2026, 6, 7, 14, 30),
        content: 'テスト駆動開発の重要性',
        selfDifficulty: 4,
        aiDifficulty: QuestRank.S,
      );

      await box.put('r1', reflection);
      final loaded = box.get('r1');

      expect(loaded, isNotNull);
      expect(loaded!.id, 'r1');
      expect(loaded.taskId, 't99');
      expect(loaded.date, DateTime(2026, 6, 7, 14, 30));
      expect(loaded.content, 'テスト駆動開発の重要性');
      expect(loaded.selfDifficulty, 4);
      expect(loaded.aiDifficulty, QuestRank.S);
    });

    test('multiple reflections', () async {
      final box = await Hive.openBox<Reflection>('test_multi');

      for (int i = 0; i < 5; i++) {
        await box.put('r$i', Reflection(
          id: 'r$i',
          taskId: 't$i',
          date: DateTime(2026, 6, i + 1),
          content: '学習 $i',
          selfDifficulty: (i % 5) + 1,
          aiDifficulty: QuestRank.values[i % 3],
        ));
      }

      expect(box.length, 5);
      final all = box.values.toList();
      expect(all.length, 5);
    });

    test('empty content is preserved', () async {
      final box = await Hive.openBox<Reflection>('test_empty');
      final reflection = Reflection(
        id: 'r0',
        taskId: 't0',
        date: DateTime.now(),
        content: '',
        selfDifficulty: 2,
        aiDifficulty: QuestRank.B,
      );

      await box.put('r0', reflection);
      final loaded = box.get('r0');
      expect(loaded!.content, '');
    });
  });
}
