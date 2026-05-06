import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/data/player_repository.dart';
import 'package:rpg_todo/features/guild/data/task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:hive/hive.dart';
import 'dart:io';

/// テスト時にエラーをthrowする PlayerRepository のモック
class FailingPlayerRepository extends PlayerRepository {
  final Object error;
  FailingPlayerRepository(this.error);

  @override
  Future<Player> loadPlayer() async {
    throw error;
  }
}

/// テスト時にエラーをthrowする TaskRepository のモック
class FailingTaskRepository extends TaskRepository {
  final Object error;
  FailingTaskRepository(this.error);

  @override
  Future<List<Task>> loadTasks() async {
    throw error;
  }
}

/// TypeAdapter を安全に登録する（他テストで登録済みの場合は無視）
void _safeRegisterAdapter<T>(TypeAdapter<T> adapter) {
  try {
    Hive.registerAdapter(adapter);
  } on HiveError {
    // 既に登録済み
  }
}

void main() {
  late Directory testDir;

  setUpAll(() async {
    testDir = Directory(
        '${Directory.systemTemp.path}/vm_test_${DateTime.now().millisecondsSinceEpoch}');
    Hive.init(testDir.path);
    _safeRegisterAdapter(TaskAdapter());
    _safeRegisterAdapter(TaskStatusAdapter());
    _safeRegisterAdapter(QuestionRankAdapter());
    _safeRegisterAdapter(PlayerAdapter());
    _safeRegisterAdapter(JobAdapter());
    _safeRegisterAdapter(RepeatIntervalAdapter());
    _safeRegisterAdapter(SubTaskAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('GameViewModel 永続化テスト（実Hive）', () {
    tearDown(() async {
      try { await Hive.deleteBoxFromDisk(PlayerRepository.boxName); } catch (_) {}
      try { await Hive.deleteBoxFromDisk(TaskRepository.boxName); } catch (_) {}
      try { await Hive.deleteBoxFromDisk('settingsBox'); } catch (_) {}
      try { await Hive.deleteBoxFromDisk('tutorialBox'); } catch (_) {}
    });

    test('タスク完了（Bランク）が永続化され、再読み込みでレベル・タスク状態が維持される', () async {
      // 1. 最初の ViewModel で操作
      final vm1 = GameViewModel();
      await _waitForLoad(vm1);

      vm1.addTask('テストクエスト', rank: QuestRank.B);

      // タスクを受け入れて完了（Bランク=100EXP → Lv1→Lv2）
      final taskId = vm1.tasks.first.id;
      vm1.acceptTask(taskId);
      final result = vm1.completeTask(taskId);

      expect(result, isNotNull);
      expect(result!['leveledUp'], true); // 100EXP → Lv1→Lv2
      expect(result['baseExp'], 100);

      // 保存を待つ
      await Future.delayed(const Duration(milliseconds: 200));

      // 2. 新しい ViewModel で読み込み
      final vm2 = GameViewModel();
      await _waitForLoad(vm2);

      // 検証: タスクは完了状態で永続化されている
      expect(vm2.tasks.length, 1);
      expect(vm2.tasks.first.isCompleted, true);
      expect(vm2.tasks.first.status, TaskStatus.inGuild);
      // 検証: プレイヤーのレベルが維持されている
      expect(vm2.player.level, 2);
      // 検証: コインが獲得されている
      expect(vm2.player.coins, greaterThan(0));
      // 検証: 累計タスク完了数
      expect(vm2.player.totalTasksCompleted, 1);
    });

    test('複数タスクの完了が永続化される', () async {
      final vm1 = GameViewModel();
      await _waitForLoad(vm1);

      // 3つのタスクを追加して完了
      vm1.addTask('クエスト1', rank: QuestRank.B);
      vm1.addTask('クエスト2', rank: QuestRank.B);
      vm1.addTask('クエスト3', rank: QuestRank.B);

      for (final t in List<Task>.from(vm1.tasks)) {
        vm1.acceptTask(t.id);
        vm1.completeTask(t.id);
      }

      await Future.delayed(const Duration(milliseconds: 200));

      final vm2 = GameViewModel();
      await _waitForLoad(vm2);

      // 全タスクが完了状態
      expect(vm2.tasks.length, 3);
      expect(vm2.tasks.every((t) => t.isCompleted), true);
      // プレイヤーデータも維持
      expect(vm2.player.totalTasksCompleted, 3);
    });

    test('プレイヤーデータ（宝石・職業）が永続化される', () async {
      final vm1 = GameViewModel();
      await _waitForLoad(vm1);

      // 直接プレイヤーを操作してから保存
      vm1.addGems(50);
      vm1.changeJob(Job.warrior);

      await Future.delayed(const Duration(milliseconds: 200));

      final vm2 = GameViewModel();
      await _waitForLoad(vm2);

      expect(vm2.player.gems, 50);
      expect(vm2.player.currentJob, Job.warrior);
    });
  });

  group('GameViewModel データ保護テスト', () {
    test('PlayerRepository 読み込み失敗時に loadData がクラッシュせず isLoaded=true になる',
        () async {
      final vm = GameViewModel(
        playerRepository: FailingPlayerRepository(HiveError('テスト用エラー')),
        taskRepository: TaskRepository(),
        settingsRepository: SettingsRepository(),
      );

      await _waitForLoad(vm);

      // ViewModel はクラッシュせず、動作を継続する
      expect(vm.isLoaded, true);
      expect(vm.player.level, 1); // デフォルト値
      expect(vm.tasks, isEmpty);
    });

    test('TaskRepository 読み込み失敗時に loadData がクラッシュせず isLoaded=true になる',
        () async {
      final vm = GameViewModel(
        playerRepository: PlayerRepository(),
        taskRepository: FailingTaskRepository(HiveError('テスト用エラー')),
        settingsRepository: SettingsRepository(),
      );

      await _waitForLoad(vm);

      expect(vm.isLoaded, true);
      expect(vm.tasks, isEmpty);
    });

    test('読み込み失敗時も _notifyAndSave が例外を投げず、ユーザー操作が可能であることを確認', () async {
      // PlayerRepository が失敗する ViewModel を作成
      final vm = GameViewModel(
        playerRepository: FailingPlayerRepository(HiveError('テスト用エラー')),
        taskRepository: TaskRepository(),
        settingsRepository: SettingsRepository(),
      );

      await _waitForLoad(vm);

      // v1.6: ロード失敗時もユーザー操作はブロックされず、saveData が実行される
      // （Repository 層で破損 Box は削除済みのため安全）
      expect(() => vm.addGems(100), returnsNormally);
      expect(() => vm.addTask('テスト', rank: QuestRank.B), returnsNormally);
      expect(vm.player.gems, 100); // 宝石が実際に追加されている
      expect(vm.tasks.length, 1); // タスクが実際に追加されている
    });
  });

  group('TaskAdapter ラウンドトリップ', () {
    late Box<Task> box;

    setUp(() async {
      box = await Hive.openBox<Task>('task_adapter_test_box');
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    test('完了済みタスクの読み書きが一致する', () async {
      final task = Task(
        id: 'test-id-1',
        title: '討伐済みクエスト',
        status: TaskStatus.inGuild,
        isCompleted: true,
        rank: QuestRank.S,
      );

      await box.put(task.id, task);
      final restored = box.get(task.id)!;

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.isCompleted, true);
      expect(restored.status, TaskStatus.inGuild);
      expect(restored.rank, QuestRank.S);
    });

    test('未完了タスクの読み書きが一致する', () async {
      final task = Task(
        id: 'test-id-2',
        title: '未討伐クエスト',
      );

      await box.put(task.id, task);
      final restored = box.get(task.id)!;

      expect(restored.isCompleted, false);
      expect(restored.status, TaskStatus.inGuild);
    });
  });

  group('GameViewModel ビジネスロジックテスト', () {
    tearDown(() async {
      try { await Hive.deleteBoxFromDisk(PlayerRepository.boxName); } catch (_) {}
      try { await Hive.deleteBoxFromDisk(TaskRepository.boxName); } catch (_) {}
      try { await Hive.deleteBoxFromDisk('settingsBox'); } catch (_) {}
      try { await Hive.deleteBoxFromDisk('tutorialBox'); } catch (_) {}
    });

    // --- (1) dailyEstimatedMinutes ---
    test('dailyEstimatedMinutes はアクティブタスクのtargetTimeMinutes合計を返す', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('タスク1', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('タスク2', rank: QuestRank.A, targetTimeMinutes: 60);
      vm.addTask('タスク3', rank: QuestRank.S, targetTimeMinutes: 120);

      // S/Aランク受注にはレベルが必要
      vm.player.jobLevels[vm.player.currentJob] = 10;

      for (final t in List<Task>.from(vm.tasks)) {
        vm.acceptTask(t.id);
      }

      expect(vm.dailyEstimatedMinutes, 30 + 60 + 120);
    });

    test('dailyEstimatedMinutes はtargetTimeMinutesがnullのタスクを無視する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('タスク1', rank: QuestRank.B, targetTimeMinutes: 45);
      vm.addTask('タスク2', rank: QuestRank.B); // null → 0扱い
      vm.acceptTask(vm.tasks[0].id);
      vm.acceptTask(vm.tasks[1].id);

      expect(vm.dailyEstimatedMinutes, 45);
    });

    test('dailyEstimatedMinutes はギルド内のタスクを含まない', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('アクティブ', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('ギルド待機', rank: QuestRank.B, targetTimeMinutes: 60);

      vm.acceptTask(vm.tasks[0].id);

      expect(vm.dailyEstimatedMinutes, 30);
    });

    test('dailyEstimatedMinutes は全タスクがギルド内なら0を返す', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('ギルド1', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('ギルド2', rank: QuestRank.B, targetTimeMinutes: 60);

      expect(vm.dailyEstimatedMinutes, 0);
    });

    // --- (2) guildEstimatedMinutes ---
    test('guildEstimatedMinutes はギルドタスクのtargetTimeMinutes合計を返す', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('ギルド1', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('ギルド2', rank: QuestRank.A, targetTimeMinutes: 60);

      expect(vm.guildEstimatedMinutes, 90);
    });

    test('guildEstimatedMinutes はアクティブタスクを含まない', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('ギルド', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('アクティブ', rank: QuestRank.B, targetTimeMinutes: 60);

      vm.acceptTask(vm.tasks[1].id);

      expect(vm.guildEstimatedMinutes, 30);
    });

    test('guildEstimatedMinutes はtargetTimeMinutesがnullのタスクを無視する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('ギルド1', rank: QuestRank.B); // null
      vm.addTask('ギルド2', rank: QuestRank.B, targetTimeMinutes: 45);

      expect(vm.guildEstimatedMinutes, 45);
    });

    // --- (3) completeTask() XP calculations for each rank ---
    test('completeTask() BランクはXP=100, coins=10を付与する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('クエストB', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100);
      expect(result['coinsGained'], 10);
    });

    test('completeTask() AランクはXP=300, coins=30を付与する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      // Aランク受注にはLv5以上が必要
      vm.player.jobLevels[vm.player.currentJob] = 5;

      vm.addTask('クエストA', rank: QuestRank.A);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 300);
      expect(result['coinsGained'], 30);
    });

    test('completeTask() SランクはXP=1000, coins=100を付与する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      // Sランク受注にはLv10以上が必要
      vm.player.jobLevels[vm.player.currentJob] = 10;

      vm.addTask('クエストS', rank: QuestRank.S);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 1000);
      // coins はレアドロップ等で変動するため、存在のみ確認
      expect(result['coinsGained'], isA<int>());
    });

    // --- (4) completeTask() with warrior combo bonus ---
    test('Warriorコンボ: 戦士でタスク完了時にコンボカウントが増加しボーナスが加算される', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.warrior);
      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(vm.player.comboCount, 1);
      // 100 base + 10 (comboCount=1 * 10) = 110
      expect(result!['baseExp'], 110);
      // comboCount>1 でないとボーナスメッセージは出ない
    });

    test('Warriorコンボ: 連続タスクでコンボが累積する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.warrior);

      // 1回目
      vm.addTask('クエスト1', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);
      vm.completeTask(vm.tasks[0].id);
      expect(vm.player.comboCount, 1);

      // 2回目
      vm.addTask('クエスト2', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[1].id);
      final result2 = vm.completeTask(vm.tasks[1].id);
      expect(vm.player.comboCount, 2);
      // 100 base + 20 (comboCount=2 * 10) = 120
      expect(result2!['baseExp'], 120);
      expect(
          result2['bonusMessages'], contains('⚔️ 2コンボ！ +20 EXP'));
    });

    test('Warrior以外の職業ではcompleteTaskでコンボがリセットされる', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.adventurer);
      vm.player.comboCount = 5; // 手動で高コンボ状態に

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);
      vm.completeTask(vm.tasks[0].id);

      expect(vm.player.comboCount, 0);
    });

    // --- (5) completeTask() with title bonus (+5%) ---
    test('称号ボーナス: equippedTitleが設定されているとEXPが+5%される', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      // 称号を手動で追加して装備
      vm.player.titles.add('テスト称号');
      vm.equipTitle('テスト称号');

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      // 100 * 1.05 = 105
      expect(result!['baseExp'], 105);
    });

    test('称号ボーナス: 称号未装備時はEXPボーナスなし', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      expect(vm.player.equippedTitle, isNull);

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100); // ボーナスなし
    });

    test('称号ボーナス: 称号を外すとボーナスが無効になる', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      // 称号を付けてから外す
      vm.player.titles.add('テスト称号');
      vm.equipTitle('テスト称号');
      expect(vm.player.equippedTitle, 'テスト称号');

      vm.equipTitle(''); // 空文字で外す
      expect(vm.player.equippedTitle, isNull);

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100); // ボーナスなし
    });

    // --- (6) completeTask() with fatigue multiplier ---
    test('疲労補正: 通常時（dailyTasksCompleted=0）はXPが1.0倍', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 0;

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100); // 1.0倍
      expect(result['coinsGained'], 10);
    });

    test('疲労補正: 警告域（dailyTasksCompleted=5）ではXPが0.5倍', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 5; // warnThreshold=5+0=5

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 50); // 100 * 0.5
      expect(result['coinsGained'], 5); // 10 * 0.5
      expect(result['bonusMessages'],
          contains('🍺 疲れが溜まってきたぞ。宿屋で一息つくか？'));
    });

    test('疲労補正: 重度域（dailyTasksCompleted=10）ではXPが0.1倍', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 10; // severeThreshold=10+0=10

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 10); // 100 * 0.1
      expect(result['coinsGained'], 1); // 10 * 0.1
      expect(result['bonusMessages'],
          contains('🌙 今日の英雄は十分戦った。宿屋で休んで明日に備えよ！'));
    });

    // --- (7) completeTask() with rare drop chance ---
    test('レアドロップ: 結果にbonusMessagesが含まれcoinsGainedが基本値以上である', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['bonusMessages'], isA<List<String>>());
      // coinsGainedは10以上（レアドロ時は追加コイン）
      expect(result['coinsGained'], greaterThanOrEqualTo(10));
    });

    test('レアドロップ: dropChanceがレベルに応じて上昇する構造確認', () async {
      // level=1 → dropChance = max(0.01, 1*0.02=0.02) = 0.02
      // level=25 → dropChance = min(0.5, 25*0.02=0.5) = 0.5
      // 構造確認のため、高レベルで複数回試行しレアドロの発生を観測
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.player.jobLevels[vm.player.currentJob] = 50; // dropChance=0.5

      int rareCount = 0;
      const trials = 20;
      for (int i = 0; i < trials; i++) {
        vm.addTask('クエスト$i', rank: QuestRank.B);
        vm.acceptTask(vm.tasks[i].id);
        final result = vm.completeTask(vm.tasks[i].id);
        if (result != null &&
            result['bonusMessages']
                .any((m) => m.toString().contains('レアドロップ'))) {
          rareCount++;
        }
      }
      // dropChance=0.5なので稀にしか出ないことはない
      expect(rareCount, greaterThan(0));
    });

    // --- (8) completeTask() triggering mission completion ---
    test('デイリーミッション: 3タスク目完了時に+200コイン', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 2;

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      // 基本10 + デイリー200 = 210
      expect(result!['coinsGained'], 210);
      expect(result['bonusMessages'],
          contains('📅 デイリーミッション達成！ +200金貨'));
      expect(vm.player.dailyTasksCompleted, 3);
    });

    test('デイリーミッション: 3タスク未満ではデイリーボーナスなし', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 0;

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['coinsGained'], 10); // 基本のみ
      expect(result['bonusMessages'],
          isNot(contains('📅 デイリーミッション達成！')));
    });

    test('ウィークリーミッション: 初回Sランクで+500コイン', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.jobLevels[vm.player.currentJob] = 10;
      vm.player.weeklySRankCompleted = 0;

      vm.addTask('Sクエスト', rank: QuestRank.S);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      // 基本100 + ウィークリー500 = 600
      expect(result!['coinsGained'], 600);
      expect(result['bonusMessages'],
          contains('🏆 ウィークリーSランク達成！ +500金貨'));
      expect(vm.player.weeklySRankCompleted, 1);
    });

    // --- (9) completeTask() returning null when sub-tasks incomplete ---
    test('サブタスク未完了: Wizard状態でサブタスク未完了ならnullを返す', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.wizard);

      vm.addTask('サブタスク付き', rank: QuestRank.B, subTasks: [
        SubTask(title: 'ステップ1'),
        SubTask(title: 'ステップ2'),
      ]);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNull);
    });

    test('サブタスク完了: Wizard状態で全サブタスク完了なら成功する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.wizard);

      vm.addTask('サブタスク付き', rank: QuestRank.B, subTasks: [
        SubTask(title: 'ステップ1', isCompleted: true),
        SubTask(title: 'ステップ2', isCompleted: true),
      ]);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100);
    });

    test('サブタスク未完了: Wizard状態でなければサブタスク未完了でも成功する', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      // Adventurer（非Wizard）
      vm.addTask('サブタスク付き', rank: QuestRank.B, subTasks: [
        SubTask(title: 'ステップ1'), // 未完了
      ]);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
    });

    test('サブタスク: toggleSubTaskで1つずつ完了させてから全体完了できる', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.wizard);

      vm.addTask('サブタスク付き', rank: QuestRank.B, subTasks: [
        SubTask(title: 'ステップ1'),
        SubTask(title: 'ステップ2'),
      ]);
      vm.acceptTask(vm.tasks[0].id);

      // 1つずつ完了
      vm.toggleSubTask(vm.tasks[0].id, 0);
      vm.toggleSubTask(vm.tasks[0].id, 1);

      expect(vm.tasks[0].subTasks[0].isCompleted, true);
      expect(vm.tasks[0].subTasks[1].isCompleted, true);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
    });

    // --- (10) completeTask() with repeat interval (cleric skill) ---
    test('繰り返しタスク: Clericで繰り返しタスク完了時はisCompleted=false、最終完了日時が記録される',
        () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.cleric);

      vm.addTask('毎日クエスト', rank: QuestRank.B,
          repeatInterval: RepeatInterval.daily);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);

      final task = vm.tasks[0];
      expect(task.isCompleted, false);
      expect(task.lastCompletedAt, isNotNull);
      expect(task.status, TaskStatus.active); // アクティブのまま継続
    });

    test('繰り返しタスク: Cleric以外では通常通りisCompleted=trueになる', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      // Adventurer（cleric スキルなし）
      vm.addTask('毎日クエスト', rank: QuestRank.B,
          repeatInterval: RepeatInterval.daily);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);

      final task = vm.tasks[0];
      expect(task.isCompleted, true);
      expect(task.status, TaskStatus.inGuild);
    });

    test('繰り返しタスク: ClericでrepeatInterval=noneの通常タスクは完了扱いになる', () async {
      final vm = GameViewModel();
      await _waitForLoad(vm);

      vm.changeJob(Job.cleric);

      vm.addTask('通常クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);

      final task = vm.tasks[0];
      expect(task.isCompleted, true);
      expect(task.status, TaskStatus.inGuild);
    });
  });
}

/// GameViewModel.loadData() の非同期完了を待つヘルパー
Future<void> _waitForLoad(GameViewModel vm,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final start = DateTime.now();
  while (!vm.isLoaded) {
    if (DateTime.now().difference(start) > timeout) {
      throw Exception('GameViewModel のロードがタイムアウトしました');
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
  // 微小な追加待機で非同期処理の完了を保証
  await Future.delayed(const Duration(milliseconds: 50));
}
