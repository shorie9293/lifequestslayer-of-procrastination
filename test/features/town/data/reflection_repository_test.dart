import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// fprint = forced print (always prints even in test)
void fprint(String msg) => print('[REFLECTION_REPO_TEST] $msg');

void main() {
  late ReflectionRepository repo;

  setUpAll(() async {
    final testDir = Directory(
        '${Directory.systemTemp.path}/reflection_repo_test_${DateTime.now().millisecondsSinceEpoch}');
    if (!testDir.existsSync()) {
      testDir.createSync(recursive: true);
    }
    Hive.init(testDir.path);
    Hive.registerAdapter(ReflectionAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
  });

  setUp(() async {
    repo = ReflectionRepository();
    // Pre-open box so test helper works before first save/getAll call
    try {
      await Hive.openBox<Reflection>('reflections');
    } catch (_) {}
  });

  tearDown(() async {
    try {
      await repo.close();
    } catch (_) {}
    // Clean up box (use deleteBoxFromDisk which works even after close)
    try {
      await Hive.deleteBoxFromDisk('reflections');
    } catch (_) {}
  });

  group('ReflectionRepository save/getAll', () {
    test('save then getAll returns saved reflection', () async {
      final reflection = Reflection(
        id: 'ref-1',
        taskId: 'task-1',
        date: DateTime(2026, 6, 7),
        content: '小さく始めるのが大事',
        selfDifficulty: 3,
        aiDifficulty: QuestRank.A,
      );
      await repo.save(reflection);
      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all[0].id, 'ref-1');
      expect(all[0].taskId, 'task-1');
      expect(all[0].date, DateTime(2026, 6, 7));
      expect(all[0].content, '小さく始めるのが大事');
      expect(all[0].selfDifficulty, 3);
      expect(all[0].aiDifficulty, QuestRank.A);
    });

    test('getAll returns reflections sorted by date descending', () async {
      await repo.save(Reflection(
        id: 'old',
        taskId: 't1',
        date: DateTime(2026, 1, 1),
        content: 'Oldest',
        selfDifficulty: 1,
        aiDifficulty: QuestRank.B,
      ));
      await repo.save(Reflection(
        id: 'mid',
        taskId: 't2',
        date: DateTime(2026, 3, 15),
        content: 'Middle',
        selfDifficulty: 3,
        aiDifficulty: QuestRank.A,
      ));
      await repo.save(Reflection(
        id: 'new',
        taskId: 't3',
        date: DateTime(2026, 12, 31),
        content: 'Newest',
        selfDifficulty: 5,
        aiDifficulty: QuestRank.S,
      ));

      final all = await repo.getAll();
      expect(all.length, 3);
      expect(all[0].id, 'new'); // newest first
      expect(all[1].id, 'mid');
      expect(all[2].id, 'old'); // oldest last
    });
  });

  group('ReflectionRepository getByDateRange', () {
    test('filters reflections within date range', () async {
      await repo.save(Reflection(
        id: 'r1',
        taskId: 't1',
        date: DateTime(2026, 6, 1),
        content: 'June 1',
        selfDifficulty: 2,
        aiDifficulty: QuestRank.B,
      ));
      await repo.save(Reflection(
        id: 'r2',
        taskId: 't2',
        date: DateTime(2026, 6, 5),
        content: 'June 5',
        selfDifficulty: 3,
        aiDifficulty: QuestRank.A,
      ));
      await repo.save(Reflection(
        id: 'r3',
        taskId: 't3',
        date: DateTime(2026, 6, 10),
        content: 'June 10',
        selfDifficulty: 4,
        aiDifficulty: QuestRank.S,
      ));
      await repo.save(Reflection(
        id: 'r4',
        taskId: 't4',
        date: DateTime(2026, 6, 15),
        content: 'June 15',
        selfDifficulty: 1,
        aiDifficulty: QuestRank.B,
      ));

      // Range: June 3 to June 12 → should include r2 and r3 only
      final filtered = await repo.getByDateRange(
        DateTime(2026, 6, 3),
        DateTime(2026, 6, 12),
      );
      expect(filtered.length, 2);
      expect(filtered.any((r) => r.id == 'r2'), isTrue);
      expect(filtered.any((r) => r.id == 'r3'), isTrue);
      expect(filtered.any((r) => r.id == 'r1'), isFalse);
      expect(filtered.any((r) => r.id == 'r4'), isFalse);
    });

    test('returns empty list when no reflections in range', () async {
      await repo.save(Reflection(
        id: 'early',
        taskId: 't1',
        date: DateTime(2026, 1, 1),
        content: 'Early',
        selfDifficulty: 1,
        aiDifficulty: QuestRank.B,
      ));

      final filtered = await repo.getByDateRange(
        DateTime(2026, 12, 1),
        DateTime(2026, 12, 31),
      );
      expect(filtered, isEmpty);
    });
  });

  group('ReflectionRepository getRecent', () {
    test('returns specified number of most recent reflections', () async {
      for (int i = 0; i < 10; i++) {
        await repo.save(Reflection(
          id: 'r$i',
          taskId: 't$i',
          date: DateTime(2026, 6, i + 1),
          content: 'Reflection $i',
          selfDifficulty: (i % 5) + 1,
          aiDifficulty: QuestRank.values[i % 3],
        ));
      }
      expect(await repo.getCount(), 10);

      final recent = await repo.getRecent(3);
      expect(recent.length, 3);
      // Most recent (latest date) should be first
      expect(recent[0].id, 'r9'); // June 10
      expect(recent[1].id, 'r8'); // June 9
      expect(recent[2].id, 'r7'); // June 8
    });

    test('getRecent with count larger than total returns all', () async {
      await repo.save(Reflection(
        id: 'only',
        taskId: 't1',
        date: DateTime(2026, 6, 1),
        content: 'Only one',
        selfDifficulty: 3,
        aiDifficulty: QuestRank.A,
      ));

      final recent = await repo.getRecent(5);
      expect(recent.length, 1);
      expect(recent[0].id, 'only');
    });
  });

  group('ReflectionRepository getCount', () {
    test('returns correct count of reflections', () async {
      expect(await repo.getCount(), 0);

      await repo.save(Reflection(
        id: 'c1', taskId: 't1', date: DateTime(2026, 6, 1),
        content: '', selfDifficulty: 1, aiDifficulty: QuestRank.B,
      ));
      expect(await repo.getCount(), 1);

      await repo.save(Reflection(
        id: 'c2', taskId: 't2', date: DateTime(2026, 6, 2),
        content: '', selfDifficulty: 2, aiDifficulty: QuestRank.A,
      ));
      expect(await repo.getCount(), 2);
    });
  });

  group('ReflectionRepository delete', () {
    test('delete removes only the specified reflection', () async {
      await repo.save(Reflection(
        id: 'keep', taskId: 't1', date: DateTime(2026, 6, 1),
        content: 'Keep me', selfDifficulty: 1, aiDifficulty: QuestRank.B,
      ));
      await repo.save(Reflection(
        id: 'remove', taskId: 't2', date: DateTime(2026, 6, 2),
        content: 'Remove me', selfDifficulty: 3, aiDifficulty: QuestRank.A,
      ));
      await repo.save(Reflection(
        id: 'keep2', taskId: 't3', date: DateTime(2026, 6, 3),
        content: 'Keep me too', selfDifficulty: 5, aiDifficulty: QuestRank.S,
      ));

      await repo.delete('remove');

      final all = await repo.getAll();
      expect(all.length, 2);
      expect(all.any((r) => r.id == 'keep'), isTrue);
      expect(all.any((r) => r.id == 'keep2'), isTrue);
      expect(all.any((r) => r.id == 'remove'), isFalse);
    });

    test('delete non-existent id does not crash', () async {
      await repo.save(Reflection(
        id: 'safe', taskId: 't1', date: DateTime(2026, 6, 1),
        content: 'Safe', selfDifficulty: 1, aiDifficulty: QuestRank.B,
      ));
      await repo.delete('nonexistent');
      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all[0].id, 'safe');
    });
  });

  group('ReflectionRepository clearAll', () {
    test('clearAll removes all reflections', () async {
      for (int i = 0; i < 5; i++) {
        await repo.save(Reflection(
          id: 'd$i', taskId: 't$i', date: DateTime(2026, 6, i + 1),
          content: 'Data $i', selfDifficulty: (i % 5) + 1,
          aiDifficulty: QuestRank.values[i % 3],
        ));
      }
      expect(await repo.getCount(), 5);

      await repo.clearAll();
      expect(await repo.getCount(), 0);
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('ReflectionRepository empty state safety', () {
    test('getAll returns empty list when no data', () async {
      final all = await repo.getAll();
      expect(all, isEmpty);
    });

    test('getCount returns 0 when no data', () async {
      expect(await repo.getCount(), 0);
    });

    test('getRecent returns empty list when no data', () async {
      final recent = await repo.getRecent(5);
      expect(recent, isEmpty);
    });

    test('getByDateRange returns empty list when no data', () async {
      final filtered = await repo.getByDateRange(
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
      );
      expect(filtered, isEmpty);
    });

    test('clearAll on empty box does not crash', () async {
      await repo.clearAll();
      expect(await repo.getCount(), 0);
    });
  });

  group('ReflectionRepository close/reopen', () {
    test('close then reopen works correctly', () async {
      await repo.save(Reflection(
        id: 'persist', taskId: 't1', date: DateTime(2026, 6, 7),
        content: 'Persist check', selfDifficulty: 3, aiDifficulty: QuestRank.A,
      ));
      await repo.close();
      fprint('Repo closed');

      repo = ReflectionRepository();
      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all[0].id, 'persist');
      expect(all[0].content, 'Persist check');
    });
  });
}
