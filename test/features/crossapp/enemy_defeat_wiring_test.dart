// 敵討伐エクスポーター実配線の試練（契約 v1）。
//
// wireEnemyDefeatExporter で TaskViewModel に実体が入り、completeTask（討伐成功）
// を通すと一時ディレクトリ配下の偽パスに .json / .jsonl の2ファイルが
// 契約どおり書かれることを実証する。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/crossapp/data/enemy_defeat_wiring.dart';
import 'package:rpg_todo/features/crossapp/data/rpg_enemy_defeat_exporter.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class _InMemoryTaskRepository implements ITaskRepository {
  List<Task> saved = [];

  @override
  Future<List<Task>> loadTasks() async => saved;

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    saved = List<Task>.of(tasks);
  }

  @override
  Future<void> close() async {}
}

class _MockPlayerRepository implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;

  @override
  Future<Player?> loadPlayer() async => Player();

  @override
  Future<void> savePlayer(Player player) async {}

  @override
  Future<void> close() async {}
}

Future<void> _waitForFile(File file,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!file.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('タイムアウト: ${file.path} が書かれなかった');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rpg_enemy_defeat_wiring_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('wireEnemyDefeatExporter', () {
    test('TaskViewModel にエクスポーター実体が入る', () {
      final playerVM = PlayerViewModel(_MockPlayerRepository());
      final taskVM = TaskViewModel(_InMemoryTaskRepository(), playerVM);

      expect(taskVM.enemyDefeatExporter, isNull);

      wireEnemyDefeatExporter(taskVM);

      expect(taskVM.enemyDefeatExporter, isNotNull);
      expect(taskVM.enemyDefeatExporter, isA<RpgEnemyDefeatExporter>());
    });

    test('明示注入したエクスポーターが優先される', () {
      final playerVM = PlayerViewModel(_MockPlayerRepository());
      final taskVM = TaskViewModel(_InMemoryTaskRepository(), playerVM);
      final custom = RpgEnemyDefeatExporter(
        filePath: '${tempDir.path}/custom.json',
      );

      wireEnemyDefeatExporter(taskVM, exporter: custom);

      expect(identical(taskVM.enemyDefeatExporter, custom), isTrue);
    });

    test('討伐成功で .json / .jsonl が契約どおり書かれる', () async {
      final playerVM = PlayerViewModel(_MockPlayerRepository());
      final repo = _InMemoryTaskRepository();
      final taskVM = TaskViewModel(repo, playerVM);

      final jsonPath = '${tempDir.path}/shared/rpg_enemy_defeat_events.json';
      final jsonlPath = '${tempDir.path}/shared/rpg_enemy_defeat_events.jsonl';
      wireEnemyDefeatExporter(
        taskVM,
        exporter: RpgEnemyDefeatExporter(
          filePath: jsonPath,
          clock: () => DateTime.utc(2026, 9, 1, 12, 0, 0),
        ),
      );

      taskVM.addTask('配線された討伐', rank: QuestRank.A);
      final id = taskVM.tasks.first.id;
      expect(taskVM.acceptTask(id, debugMode: true), isNull);
      final result = taskVM.completeTask(id);
      expect(result, isNotNull);
      expect(result!['baseExp'], isA<int>());
      expect(result['baseExp'] as int, greaterThan(0));

      await _waitForFile(File(jsonPath));
      await _waitForFile(File(jsonlPath));

      // A .json: 単一JSON（最後の1件）
      final single = jsonDecode(await File(jsonPath).readAsString())
          as Map<String, dynamic>;
      expect(single['event'], 'enemy_defeated');
      expect(single['taskTitle'], '配線された討伐');
      expect(single['questRank'], 'A');
      expect(single['baseExp'], result['baseExp']);
      expect(single['baseExp'] as int, greaterThan(0));
      expect(DateTime.tryParse(single['timestamp'] as String), isNotNull);

      // B .jsonl: 追記1行
      final lines = (await File(jsonlPath).readAsString())
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines, hasLength(1));
      final appended = jsonDecode(lines.first) as Map<String, dynamic>;
      expect(appended['event'], 'enemy_defeated');
      expect(appended['taskTitle'], '配線された討伐');
      expect(appended['questRank'], 'A');
      expect(appended['baseExp'], result['baseExp']);
      expect(DateTime.tryParse(appended['timestamp'] as String), isNotNull);

      // 双方のスキーマは同一
      expect(appended.keys.toList(), single.keys.toList());
      expect(appended, equals(single));
    });
  });
}
