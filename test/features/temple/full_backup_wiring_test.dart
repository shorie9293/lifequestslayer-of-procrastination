// 寺院画面のバックアップ/復元配線の試練。
//
// TempleScreen の onPressed から呼ばれる @visibleForTesting の
// buildBackupJsonWithStorage / applyRestore を、InMemoryBackupStorage 経由で
// 検証する（プラグイン: path_provider / share_plus / file_picker は叩かない）。

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/services/full_backup.dart';
import 'package:rpg_todo/domain/services/reflection_backup_codec.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/temple/data/backup_storage.dart';
import 'package:rpg_todo/features/temple/presentation/temple_screen.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player;
  _MockPlayerRepo([Player? player]) : _player = player ?? Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

class _FakeTaskRepository implements ITaskRepository {
  @override
  Future<List<Task>> loadTasks() async => [];
  @override
  Future<void> saveTasks(List<Task> tasks) async {}
  @override
  Future<void> close() async {}
}

void main() {
  group('寺院バックアップ配線 — backup → restore 往復', () {
    test('boxes が InMemoryBackupStorage 経由で往復する', () async {
      final playerVM = PlayerViewModel(_MockPlayerRepo());
      await playerVM.load();

      final tasks = <Task>[
        Task(id: 't1', title: '魔物討伐', rank: QuestRank.B),
      ];

      // バックアップ側: capture に Reflection を混ぜる
      final source = InMemoryBackupStorage({
        'battle_records': {'r1': 'record-json'},
        'settingsBox': {'theme': 'dark', 'volume': 0.5},
        'reflections': {
          'ref1': ReflectionBackupCodec.toMap(
            Reflection(
              id: 'ref1',
              taskId: 't1',
              date: DateTime.utc(2026, 10, 14),
              content: '学び',
              selfDifficulty: 4,
              aiDifficulty: QuestRank.S,
              sentiment: 'kaishin',
            ),
          ),
        },
      });

      final json = await TempleScreen.buildBackupJsonWithStorage(
        player: playerVM.player,
        tasks: tasks,
        storage: source,
      );

      // version 2 形式で boxes が入っていること
      final data = FullBackupService().decode(json);
      expect(data, isNotNull);
      expect(data!.version, 2);
      expect(data.hasBoxes, isTrue);
      expect(data.boxCount, 3);
      expect(data.entryCount, 4); // 1 + 2 + 1
      expect(data.tasks.first.id, 't1');

      // 復元側: 空の storage へ applyRestore
      final targetPlayerVM = PlayerViewModel(_MockPlayerRepo());
      await targetPlayerVM.load();
      final taskVM = TaskViewModel(_FakeTaskRepository(), targetPlayerVM);
      final targetStorage = InMemoryBackupStorage();

      final ok = await TempleScreen.applyRestore(
        jsonString: json,
        playerVM: targetPlayerVM,
        taskVM: taskVM,
        storage: targetStorage,
      );
      expect(ok, isTrue);

      // player / tasks が復元されていること
      expect(taskVM.tasks.length, 1);
      expect(taskVM.tasks.first.id, 't1');
      expect(taskVM.tasks.first.title, '魔物討伐');

      // boxes が InMemoryBackupStorage に復元されていること
      final restored = targetStorage.snapshot;
      expect(restored['battle_records'], {'r1': 'record-json'});
      expect(restored['settingsBox'], {'theme': 'dark', 'volume': 0.5});
      expect(restored['reflections']!.keys, ['ref1']);
    });

    test('capture→encode→decode→restore で Reflection がオブジェクトに戻る', () async {
      final playerVM = PlayerViewModel(_MockPlayerRepo());
      await playerVM.load();

      final original = Reflection(
        id: 'ref2',
        taskId: 't2',
        date: DateTime.utc(2026, 1, 2, 3, 4),
        content: '往復検証',
        selfDifficulty: 2,
        aiDifficulty: QuestRank.B,
        sentiment: null,
      );
      final source = InMemoryBackupStorage({
        'reflections': {'ref2': ReflectionBackupCodec.toMap(original)},
      });

      final json = await TempleScreen.buildBackupJsonWithStorage(
        player: playerVM.player,
        tasks: const [],
        storage: source,
      );

      final targetStorage = InMemoryBackupStorage();
      await targetStorage.restore(
        FullBackupService().decode(json)!.boxes,
      );

      final restored = targetStorage.snapshot['reflections']!['ref2'];
      expect(restored, isA<Reflection>());
      final r = restored as Reflection;
      expect(r.id, 'ref2');
      expect(r.aiDifficulty, QuestRank.B);
      expect(r.sentiment, isNull);
      expect(r.date, original.date);
    });

    test('破損 JSON では applyRestore が false を返し何も書き換えない', () async {
      final playerVM = PlayerViewModel(_MockPlayerRepo());
      await playerVM.load();
      final taskVM = TaskViewModel(_FakeTaskRepository(), playerVM);
      taskVM.addTasks(['既存クエスト'], QuestRank.A);
      final beforeTasks = taskVM.tasks.length;
      final storage = InMemoryBackupStorage();

      final ok = await TempleScreen.applyRestore(
        jsonString: '{{not json',
        playerVM: playerVM,
        taskVM: taskVM,
        storage: storage,
      );

      expect(ok, isFalse);
      expect(taskVM.tasks.length, beforeTasks);
      expect(storage.snapshot, isEmpty);
    });
  });
}
