import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';

void main() {
  late FullBackupService service;

  setUp(() {
    service = FullBackupService();
  });

  Player makePlayer() => Player(coins: 100);

  List<Task> makeTasks() => [
        Task(id: 't1', title: 'クエスト1', rank: QuestRank.S),
        Task(id: 't2', title: 'クエスト2', rank: QuestRank.B),
      ];

  Map<String, Map<String, dynamic>> makeBoxes() => {
        'battle_records': {'rec1': {'xp': 10}, 'rec2': 'legacy-json-string'},
        'settingsBox': {'theme': 'dark', 'volume': 0.5},
      };

  group('FullBackupService - encode', () {
    test('outputs version 2 JSON', () {
      final json = service.encode(player: makePlayer(), tasks: []);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['version'], 2);
      expect(data, contains('exportedAt'));
      expect(data, contains('player'));
      expect(data, contains('tasks'));
      expect(data, contains('boxes'));
    });

    test('boxes default to empty', () {
      final json = service.encode(player: makePlayer(), tasks: []);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['boxes'], isEmpty);
    });

    test('boxes are serialized under their box names', () {
      final json = service.encode(
          player: makePlayer(), tasks: makeTasks(), boxes: makeBoxes());
      final data = jsonDecode(json) as Map<String, dynamic>;
      final boxes = data['boxes'] as Map<String, dynamic>;
      expect(boxes.keys, containsAll(['battle_records', 'settingsBox']));
      expect((boxes['battle_records'] as Map)['rec1'], {'xp': 10});
    });
  });

  group('FullBackupService - decode / round-trip', () {
    test('round-trip preserves player, tasks, boxes', () {
      final json = service.encode(
          player: makePlayer(), tasks: makeTasks(), boxes: makeBoxes());
      final data = service.decode(json);

      expect(data, isNotNull);
      expect(data!.version, 2);
      expect(data.player.coins, 100);
      expect(data.player.coins, 100);
      expect(data.tasks.length, 2);
      expect(data.tasks[0].id, 't1');
      expect(data.tasks[0].rank, QuestRank.S);
      expect(data.tasks[1].title, 'クエスト2');
      expect(data.boxes, makeBoxes());
    });

    test('decode of version 1 JSON restores with empty boxes', () {
      final v1 = jsonEncode({
        'version': 1,
        'exportedAt': '2026-05-31T09:52:00.000',
        'player': Player(coins: 42).toJson(),
        'tasks': [],
      });
      final data = service.decode(v1);
      expect(data, isNotNull);
      expect(data!.version, 1);
      expect(data.player.coins, 42);
      expect(data.boxes, isEmpty);
      expect(data.hasBoxes, isFalse);
    });

    test('malformed JSON returns null', () {
      expect(service.decode('not json'), isNull);
      expect(service.decode(''), isNull);
      expect(service.decode('[1,2,3]'), isNull); // Mapでない
      expect(service.decode('"string"'), isNull);
    });

    test('missing version returns null', () {
      final json = jsonEncode({
        'player': Player().toJson(),
        'tasks': [],
      });
      expect(service.decode(json), isNull);
    });

    test('version < 1 returns null', () {
      final json = jsonEncode({
        'version': 0,
        'player': Player().toJson(),
        'tasks': [],
      });
      expect(service.decode(json), isNull);
    });

    test('missing or invalid player/tasks returns null', () {
      expect(service.decode('{"version": 2}'), isNull);
      expect(
          service.decode(jsonEncode({
            'version': 2,
            'player': 'not-a-map',
            'tasks': [],
          })),
          isNull);
      expect(
          service.decode(jsonEncode({
            'version': 2,
            'player': Player().toJson(),
            'tasks': 'not-a-list',
          })),
          isNull);
      expect(
          service.decode(jsonEncode({
            'version': 2,
            'player': Player().toJson(),
            'tasks': [42],
          })),
          isNull);
    });

    test('non-Map box entries are ignored', () {
      final json = jsonEncode({
        'version': 2,
        'player': Player().toJson(),
        'tasks': [],
        'boxes': {
          'battle_records': {'ok': 1},
          'bad_box': 'not-a-map',
        },
      });
      final data = service.decode(json);
      expect(data, isNotNull);
      expect(data!.boxes.keys, ['battle_records']);
    });

    test('non-JSON-safe entry values are ignored, no exception', () {
      // JSON上は直列化不可能な型は存在しないが、復元側の防御を検証
      final json = jsonEncode({
        'version': 2,
        'player': Player().toJson(),
        'tasks': [],
        'boxes': {
          'settingsBox': {'ok': 'v1', 'also_ok': [1, 2, {'nested': true}]},
        },
      });
      final data = service.decode(json);
      expect(data, isNotNull);
      expect(data!.boxes['settingsBox']!.length, 2);
    });

    test('unknown top-level keys are ignored (forward compatible)', () {
      final json = jsonEncode({
        'version': 2,
        'player': Player().toJson(),
        'tasks': [],
        'boxes': {},
        'futureField': {'whatever': true},
      });
      final data = service.decode(json);
      expect(data, isNotNull);
    });

    test('unknown box names are preserved (forward compatible)', () {
      final json = jsonEncode({
        'version': 2,
        'player': Player().toJson(),
        'tasks': [],
        'boxes': {
          'some_future_box': {'k': 'v'},
        },
      });
      final data = service.decode(json);
      expect(data, isNotNull);
      expect(data!.boxes['some_future_box'], {'k': 'v'});
    });
  });

  group('FullBackupData - getters', () {
    test('hasBoxes / boxCount / entryCount / boxNames', () {
      final empty = FullBackupData(
          version: 2, exportedAt: DateTime(2026), player: makePlayer(), tasks: []);
      expect(empty.hasBoxes, isFalse);
      expect(empty.boxCount, 0);
      expect(empty.entryCount, 0);
      expect(empty.boxNames, isEmpty);

      final full = FullBackupData(
        version: 2,
        exportedAt: DateTime(2026),
        player: makePlayer(),
        tasks: [],
        boxes: makeBoxes(),
      );
      expect(full.hasBoxes, isTrue);
      expect(full.boxCount, 2);
      expect(full.entryCount, 4); // 2 + 2
      expect(full.boxNames.toSet().length, 2);
    });
  });
}
