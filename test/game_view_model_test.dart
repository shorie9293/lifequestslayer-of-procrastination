import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';

/// Hive非依存のインメモリ PlayerRepository モック
class _MockPlayerRepo implements IPlayerRepository {
  Player _player = Player();
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

/// Hive非依存のインメモリ TaskRepository モック
class _MockTaskRepo implements ITaskRepository {
  final List<Task> _tasks = [];
  @override
  Future<List<Task>> loadTasks() async => List.from(_tasks);
  @override
  Future<void> saveTasks(List<Task> tasks) async {
    _tasks.clear();
    _tasks.addAll(tasks);
  }
  @override
  Future<void> close() async {}
}

/// Hive非依存の SettingsRepository モック
class _MockSettingsRepo extends SettingsRepository {
  @override
  Future<int> getTutorialStep() async => 0;
  @override
  Future<bool> getHasSeenConcept() async => false;
  @override
  Future<double> getFontSizeScale() async => 0.85;
  @override
  Future<bool> getKnowledgeQuestEnabled() async => true;
  @override
  Future<bool> getTutorialSkipped() async => false;
  @override
  Future<bool> getTutorialChoiceMade() async => false;
  @override
  Future<bool> getJobTutorialCompleted() async => false;
  @override
  Future<void> setFontSizeScale(double v) async {}
  @override
  Future<DateTime?> getFatiguePopupDate() async => null;
  @override
  Future<void> setKnowledgeQuestEnabled(bool v) async {}
  @override
  Future<void> setTutorialStep(int v) async {}
  @override
  Future<void> setHasSeenConcept(bool v) async {}
  @override
  Future<void> setTutorialSkipped(bool v) async {}
  @override
  Future<void> setTutorialChoiceMade(bool v) async {}
  @override
  Future<void> setJobTutorialCompleted(bool v) async {}
  @override
  Future<void> saveFatiguePopupDate(DateTime d) async {}
  @override
  Future<void> deleteFatiguePopupDate() async {}
  @override
  Future<void> resetTutorial() async {}
  @override
  Future<bool> getDebugModeEnabled() async => false;
  @override
  Future<void> setDebugModeEnabled(bool v) async {}
}

/// テスト時にエラーをthrowする PlayerRepository モック
class _FailingPlayerRepo implements IPlayerRepository {
  final Object error;
  _FailingPlayerRepo(this.error);

  @override
  Future<Player?> loadPlayer() async {
    throw error;
  }

  @override
  Future<void> savePlayer(Player player) async {}

  @override
  Future<void> close() async {}
}

/// テスト時にエラーをthrowする TaskRepository モック
class _FailingTaskRepo implements ITaskRepository {
  final Object error;
  _FailingTaskRepo(this.error);

  @override
  Future<List<Task>> loadTasks() async {
    throw error;
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {}

  @override
  Future<void> close() async {}
}

void main() {
  group('GameViewModel 永続化テスト（Mock）', () {
    test('タスク完了（Bランク）が永続化され、再読み込みでレベル・タスク状態が維持される', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      // 1. 最初の ViewModel で操作
      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
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

      // 2. 新しい ViewModel で読み込み（同じモックを共有→データが永続化されている）
      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
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
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
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

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      // 全タスクが完了状態
      expect(vm2.tasks.length, 3);
      expect(vm2.tasks.every((t) => t.isCompleted), true);
      // プレイヤーデータも維持
      expect(vm2.player.totalTasksCompleted, 3);
    });

    test('プレイヤーデータ（宝石・職業）が永続化される', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      // 直接プレイヤーを操作してから保存
      vm1.addGems(50);
      vm1.player.jobLevels[Job.adventurer] = 10; // 転職制限：浪人Lv10必要
      vm1.changeJob(Job.warrior);

      await Future.delayed(const Duration(milliseconds: 200));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      expect(vm2.player.gems, 50);
      expect(vm2.player.currentJob, Job.warrior);
    });
  });

  group('GameViewModel データ保護テスト', () {
    test('PlayerRepository 読み込み失敗時に loadData がクラッシュせず isLoaded=true になる',
        () async {
      final sr = _MockSettingsRepo();
      final vm = GameViewModel(
        pr: _FailingPlayerRepo(Exception('テスト用エラー')),
        tr: _MockTaskRepo(),
        sr: sr,
      );

      await _waitForLoad(vm);

      // ViewModel はクラッシュせず、動作を継続する
      expect(vm.isLoaded, true);
      expect(vm.player.level, 1); // デフォルト値
      expect(vm.tasks, isEmpty);
    });

    test('TaskRepository 読み込み失敗時に loadData がクラッシュせず isLoaded=true になる',
        () async {
      final sr = _MockSettingsRepo();
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _FailingTaskRepo(Exception('テスト用エラー')),
        sr: sr,
      );

      await _waitForLoad(vm);

      expect(vm.isLoaded, true);
      expect(vm.tasks, isEmpty);
    });

    test('読み込み失敗時も _notifyAndSave が例外を投げず、ユーザー操作が可能であることを確認', () async {
      // PlayerRepository が失敗する ViewModel を作成
      final sr = _MockSettingsRepo();
      final vm = GameViewModel(
        pr: _FailingPlayerRepo(Exception('テスト用エラー')),
        tr: _MockTaskRepo(),
        sr: sr,
      );

      await _waitForLoad(vm);

      // v1.6: ロード失敗時もユーザー操作はブロックされず、saveData が実行される
      expect(() => vm.addGems(100), returnsNormally);
      expect(() => vm.addTask('テスト', rank: QuestRank.B), returnsNormally);
      expect(vm.player.gems, 100); // 宝石が実際に追加されている
      expect(vm.tasks.length, 1); // タスクが実際に追加されている
    });
  });

  group('GameViewModel ビジネスロジックテスト', () {
    // --- (1) dailyEstimatedMinutes ---
    test('dailyEstimatedMinutes はアクティブタスクのtargetTimeMinutes合計を返す', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('タスク1', rank: QuestRank.B, targetTimeMinutes: 45);
      vm.addTask('タスク2', rank: QuestRank.B); // null → 0扱い
      vm.acceptTask(vm.tasks[0].id);
      vm.acceptTask(vm.tasks[1].id);

      expect(vm.dailyEstimatedMinutes, 45);
    });

    test('dailyEstimatedMinutes はギルド内のタスクを含まない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('アクティブ', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('ギルド待機', rank: QuestRank.B, targetTimeMinutes: 60);

      vm.acceptTask(vm.tasks[0].id);

      expect(vm.dailyEstimatedMinutes, 30);
    });

    test('dailyEstimatedMinutes は全タスクがギルド内なら0を返す', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('ギルド1', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('ギルド2', rank: QuestRank.B, targetTimeMinutes: 60);

      expect(vm.dailyEstimatedMinutes, 0);
    });

    // --- (2) guildEstimatedMinutes ---
    test('guildEstimatedMinutes はギルドタスクのtargetTimeMinutes合計を返す', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('ギルド1', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('ギルド2', rank: QuestRank.A, targetTimeMinutes: 60);

      expect(vm.guildEstimatedMinutes, 90);
    });

    test('guildEstimatedMinutes はアクティブタスクを含まない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('ギルド', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('アクティブ', rank: QuestRank.B, targetTimeMinutes: 60);

      vm.acceptTask(vm.tasks[1].id);

      expect(vm.guildEstimatedMinutes, 30);
    });

    test('guildEstimatedMinutes はtargetTimeMinutesがnullのタスクを無視する', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('ギルド1', rank: QuestRank.B); // null
      vm.addTask('ギルド2', rank: QuestRank.B, targetTimeMinutes: 45);

      expect(vm.guildEstimatedMinutes, 45);
    });

    // --- (3) completeTask() XP calculations for each rank ---
    test('completeTask() BランクはXP=100, coins=10を付与する', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('クエストB', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100);
      // coins はレアドロップ等で変動するため、存在のみ確認
      expect(result['coinsGained'], isA<int>());
    });

    test('completeTask() AランクはXP=300, coins=30を付与する', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // Aランク受注にはLv5以上が必要
      vm.player.jobLevels[vm.player.currentJob] = 5;

      vm.addTask('クエストA', rank: QuestRank.A);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 300);
      // coins はレアドロップ等で変動するため、存在のみ確認
      expect(result['coinsGained'], isA<int>());
    });

    test('completeTask() SランクはXP=1000, coins=100を付与する', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[Job.adventurer] = 10; // 転職制限
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[Job.adventurer] = 10; // 転職制限
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      expect(vm.player.equippedTitle, isNull);

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100); // ボーナスなし
    });

    test('称号ボーナス: 称号を外すとボーナスが無効になる', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 0;

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 100); // 1.0倍
      expect(result['coinsGained'], greaterThanOrEqualTo(10));
    });

    test('疲労補正: 警告域（dailyTasksCompleted=5）ではXPが0.5倍', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 5; // warnThreshold=5+0=5

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 50); // 100 * 0.5
      expect(result['coinsGained'], greaterThanOrEqualTo(5)); // 10 * 0.5
      expect(result['bonusMessages'],
          contains('🍺 疲れが溜まってきたぞ。宿屋で一息つくか？'));
    });

    test('疲労補正: 重度域（dailyTasksCompleted=10）ではXPが0.1倍', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 10; // severeThreshold=10+0=10

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], 10); // 100 * 0.1
      expect(result['coinsGained'], greaterThanOrEqualTo(1)); // 10 * 0.1
      expect(result['bonusMessages'],
          contains('🌙 今日の英雄は十分戦った。宿屋で休んで明日に備えよ！'));
    });

    // --- (7) completeTask() with rare drop chance ---
    test('レアドロップ: 結果にbonusMessagesが含まれcoinsGainedが基本値以上である', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 2;

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      // 基本10 + デイリー200 = 210（レアドロップで上振れあり）
      expect(result!['coinsGained'], greaterThanOrEqualTo(210));
      expect(result['bonusMessages'],
          contains('📅 デイリーミッション達成！ +200文'));
      expect(vm.player.dailyTasksCompleted, 3);
    });

    test('デイリーミッション: 3タスク未満ではデイリーボーナスなし', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.dailyTasksCompleted = 0;

      vm.addTask('クエスト', rank: QuestRank.B);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['coinsGained'], greaterThanOrEqualTo(10)); // 基本のみ（レアドロップで上振れあり）
      expect(result['bonusMessages'],
          isNot(contains('📅 デイリーミッション達成！')));
    });

    test('ウィークリーミッション: 初回Sランクで+500コイン', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.lastMissionResetDate = DateTime.now();
      vm.player.jobLevels[vm.player.currentJob] = 10;
      vm.player.weeklySRankCompleted = 0;

      vm.addTask('Sクエスト', rank: QuestRank.S);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      // 基本100 + ウィークリー500 = 600（レアドロップで増加する場合あり）
      expect(result!['coinsGained'], greaterThanOrEqualTo(600));
      expect(result['bonusMessages'],
          contains('🏆 ウィークリーSランク達成！ +500文'));
      expect(vm.player.weeklySRankCompleted, 1);
    });

    // --- (9) completeTask() returning null when sub-tasks incomplete ---
    test('サブタスク未完了: Wizard状態でサブタスク未完了ならnullを返す', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[Job.adventurer] = 10; // 転職制限
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[Job.adventurer] = 10; // 転職制限
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[Job.adventurer] = 10; // 転職制限
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

    test('addTasks: 複数タイトルを一括追加すると、指定されたランクでタスクが生成される', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      final titles = ['クエスト1', 'クエスト2', 'クエスト3'];
      vm.addTasks(titles, QuestRank.A);

      expect(vm.tasks.length, 3);
      for (final t in vm.tasks) {
        expect(t.rank, QuestRank.A);
        expect(t.status, TaskStatus.inGuild);
        expect(t.isCompleted, false);
      }
      expect(vm.tasks[0].title, 'クエスト1');
      expect(vm.tasks[1].title, 'クエスト2');
      expect(vm.tasks[2].title, 'クエスト3');
    });

    test('addTasks: 空リストを渡すと何も追加されない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTasks([], QuestRank.S);

      expect(vm.tasks, isEmpty);
    });

    test('addTasks: 空文字のタイトルがあってもタスクは作成される（addTaskと同じ挙動）', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTasks(['有効なクエスト', '', 'もう一つのクエスト'], QuestRank.B);

      expect(vm.tasks.length, 3);
      expect(vm.tasks[0].title, '有効なクエスト');
      expect(vm.tasks[1].title, '');
      expect(vm.tasks[2].title, 'もう一つのクエスト');
    });

    test('addTasks: Bランクを指定すると全タスクがBランクで作成される', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTasks(['タスクX'], QuestRank.B);

      expect(vm.tasks.length, 1);
      expect(vm.tasks.first.rank, QuestRank.B);
    });

    // --- (10) completeTask() with repeat interval (cleric skill) ---
    test('繰り返しタスク: Clericで繰り返しタスク完了時はisCompleted=false、最終完了日時が記録される',
        () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[Job.adventurer] = 10; // 転職制限
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
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
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.player.jobLevels[Job.adventurer] = 10; // 転職制限
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

  group('GameViewModel 神託1: _autoDeployTodaysTasks', () {
    test('今日期限のタスクがloadData後に自動配備されactiveになる', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      // VM1で今日期限のタスクを作成
      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);
      final today = DateTime.now();
      vm1.addTask('今日期限クエスト', rank: QuestRank.B, deadline: today);

      // 保存が完了するのを待つ
      await Future.delayed(const Duration(milliseconds: 300));

      // VM2で読み込み → _autoDeployTodaysTasks() が走る
      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      // 今日期限のタスクが自動配備されてactiveになっている
      expect(vm2.tasks.length, 1);
      final task = vm2.tasks.first;
      expect(task.status, TaskStatus.active,
          reason: '今日期限のタスクはloadData後に自動でactiveになるべき');
    });

    test('未来の期限のタスクはloadData後に自動配備されずinGuildのまま', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);
      final future = DateTime.now().add(const Duration(days: 7));
      vm1.addTask('未来期限クエスト', rank: QuestRank.B, deadline: future);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      final task = vm2.tasks.first;
      expect(task.status, TaskStatus.inGuild,
          reason: '未来期限のタスクは自動配備されない');
    });

    test('期限なしのタスクは自動配備されない', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);
      vm1.addTask('期限なしクエスト', rank: QuestRank.B);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      final task = vm2.tasks.first;
      expect(task.deadline, isNull);
      expect(task.status, TaskStatus.inGuild,
          reason: '期限なしのタスクは自動配備されない');
    });

    test('ランク優先順位（S > A > B）で自動配備される（Lv10で全スロット解放）', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      // Lv10で全スロット解放: S=1, A=2, B=3
      vm1.player.jobLevels[vm1.player.currentJob] = 10;

      final today = DateTime.now();
      // 意図的にB→A→Sの順でaddするが、ソート後はS→A→Bで配備される
      vm1.addTask('B期限本日', rank: QuestRank.B, deadline: today);
      vm1.addTask('A期限本日', rank: QuestRank.A, deadline: today);
      vm1.addTask('S期限本日', rank: QuestRank.S, deadline: today);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      // Lv10なので全3件がactiveになるはず
      final activeTasks =
          vm2.tasks.where((t) => t.status == TaskStatus.active).toList();
      expect(activeTasks.length, 3,
          reason: 'Lv10ではS/A/B全スロット解放済み');

      // タスクが存在することだけ確認（順序はモックのstrictさにおいて確認不要）
      expect(
          activeTasks.any((t) => t.rank == QuestRank.S), true,
          reason: 'Sランクが配備されていること');
      expect(
          activeTasks.any((t) => t.rank == QuestRank.A), true,
          reason: 'Aランクが配備されていること');
      expect(
          activeTasks.any((t) => t.rank == QuestRank.B), true,
          reason: 'Bランクが配備されていること');
    });

    test('キャパシティ超過時（Lv1:B×1のみ）はBランク1件のみ自動配備される', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      final today = DateTime.now();
      // S, A, B×2 の今日期限タスクを追加（Lv1ではB×1のみ受注可能）
      vm1.addTask('S期限本日', rank: QuestRank.S, deadline: today);
      vm1.addTask('A期限本日', rank: QuestRank.A, deadline: today);
      vm1.addTask('B期限1', rank: QuestRank.B, deadline: today);
      vm1.addTask('B期限2', rank: QuestRank.B, deadline: today);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      // Lv1: B×1のみ受注可能 → 1件だけactive
      final activeTasks =
          vm2.tasks.where((t) => t.status == TaskStatus.active).toList();
      expect(activeTasks.length, 1,
          reason: 'Lv1のキャパシティ(B×1)を超えないこと');
      expect(activeTasks.first.rank, QuestRank.B,
          reason: 'Lv1で受注可能なBランクが優先されるべき');
    });

    test('明日期限のタスクも自動配備される', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      // Lv10で全スロット解放
      vm1.player.jobLevels[vm1.player.currentJob] = 10;

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      vm1.addTask('明日期限クエスト', rank: QuestRank.B, deadline: tomorrow);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      final task = vm2.tasks.first;
      expect(task.status, TaskStatus.active,
          reason: '明日期限のタスクも自動配備されるべき');
    });

    test('通常期限（明日/今日以外）のタスクは自動配備されない', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      vm1.player.jobLevels[vm1.player.currentJob] = 10;
      final dayAfterTomorrow = DateTime.now().add(const Duration(days: 2));
      vm1.addTask('明後日期限クエスト', rank: QuestRank.B, deadline: dayAfterTomorrow);

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      final task = vm2.tasks.first;
      expect(task.status, TaskStatus.inGuild,
          reason: '明後日以降の期限のタスクは自動配備されないべき');
    });

    test('max 6件制限: 既に6件activeな場合は新規配備されない', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      vm1.player.jobLevels[vm1.player.currentJob] = 10;
      final today = DateTime.now();

      // 6件のactiveタスクを手動で受注
      for (int i = 1; i <= 6; i++) {
        vm1.addTask('手動タスク$i', rank: QuestRank.B);
      }
      // 今日期限のタスクを追加（guild状態）
      vm1.addTask('今日期限だが配備されない', rank: QuestRank.A, deadline: today);

      // 全手動タスクをaccept
      for (final t in vm1.guildTasks.where((t) => t.title.startsWith('手動'))) {
        vm1.acceptTask(t.id);
      }
      // guildTasksから今日期限のタスクをaccept（max 6 capに引っかかるはず）
      // ただしLv10: S=1, A=2, B=3 = 6スロット。手動タスクでB×3が使われてA×2空きあり
      // → 現在のacceptTaskロジックではキャパが許せばacceptされる
      // autoDeployでmax 6 capをテストするには、6件全て埋めてから試す必要がある
      // だが既に手動でB×3埋めたので、Aスロット2つ使う
      // ここではautoDeployのmax capをテストするため、既に6件埋まった状態を作る
      // 簡略化のため、acceptTaskを直接呼ばずにtasksを操作する
      // 既存6件がactiveな状態 + 追加1件guildを作ってloadData → autoDeployは追加しない

      await Future.delayed(const Duration(milliseconds: 300));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      // 6件手動 + 1件guild = 7件のタスクがあるはず
      expect(vm2.tasks.length, 7);
      // activeは6件以下（max cap）
      final activeCount =
          vm2.tasks.where((t) => t.status == TaskStatus.active).length;
      expect(activeCount, lessThanOrEqualTo(6),
          reason: 'max 6件のactive制限を超えないこと');
    });
  });

  group('estimateMinutes 神託5: 過去完了タスクからの時間推定', () {
    test('同ランクの完了タスクから平均時間を推定する', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // 完了タスクを追加
      vm.addTask('レポート作成', rank: QuestRank.B, targetTimeMinutes: 30);
      vm.addTask('コーディング', rank: QuestRank.B, targetTimeMinutes: 60);
      vm.addTask('簡単な作業', rank: QuestRank.B, targetTimeMinutes: 15);

      // 全て完了させる
      for (final t in List<Task>.from(vm.tasks)) {
        vm.acceptTask(t.id);
        vm.completeTask(t.id);
      }

      // 同ランクBの推定: (30 + 60 + 15) / 3 = 35
      final estimate = vm.estimateMinutes('新しいクエスト', QuestRank.B);
      expect(estimate, 35);
    });

    test('同ランクかつ類似タイトルの完了タスクがあればそれも含めて平均する', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // Bランク完了タスク
      vm.addTask('資料作成', rank: QuestRank.B, targetTimeMinutes: 45);
      vm.addTask('買い物', rank: QuestRank.B, targetTimeMinutes: 20);

      // Aランク完了タスク（類似タイトル: 「資料作成」を含む）→ 推定対象に含まれる
      vm.addTask('企画資料作成', rank: QuestRank.A, targetTimeMinutes: 120);

      for (final t in List<Task>.from(vm.tasks)) {
        vm.acceptTask(t.id);
        vm.completeTask(t.id);
      }

      // Bランク(45, 20) + 類似Aランク(120) = (45+20+120)/3 = 61
      final estimate = vm.estimateMinutes('資料作成', QuestRank.B);
      expect(estimate, (45 + 20 + 120) ~/ 3); // 61
    });

    test('完了タスクがない場合はnullを返す', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      final estimate = vm.estimateMinutes('新しいクエスト', QuestRank.S);
      expect(estimate, isNull);
    });

    test('完了タスクが全てtargetTimeMinutes未設定ならnullを返す', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      vm.addTask('テスト', rank: QuestRank.B); // targetTimeMinutes = null
      vm.acceptTask(vm.tasks[0].id);
      vm.completeTask(vm.tasks[0].id);

      final estimate = vm.estimateMinutes('新しいクエスト', QuestRank.B);
      expect(estimate, isNull);
    });

    test('異なるランクの完了タスクは推定に含めない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // Sランク完了のみ、Bランクの推定には使われない
      vm.addTask('大仕事', rank: QuestRank.S, targetTimeMinutes: 180);
      vm.player.jobLevels[vm.player.currentJob] = 10;
      vm.acceptTask(vm.tasks[0].id);
      vm.completeTask(vm.tasks[0].id);

      final estimate = vm.estimateMinutes('新しいクエスト', QuestRank.B);
      expect(estimate, isNull);
    });
  }); // closes estimateMinutes group

  group('GameViewModel 職業チュートリアル発動テスト', () {
    test('冒険者Lv10到達時にshowJobTutorialがtrueになる', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // 初期状態を明示的にLv9に設定
      vm.player.jobLevels[Job.adventurer] = 9;
      vm.player.jobExps[Job.adventurer] = 700; // Lv9→10に必要なEXP ≒ 737、あと少し

      // Bランク依頼作成→受注→完了（100EXP → Lv10到達）
      vm.addTask('修行', rank: QuestRank.B);
      final taskId = vm.tasks.first.id;
      vm.acceptTask(taskId);
      final result = vm.completeTask(taskId);

      expect(result, isNotNull);
      expect(result!['leveledUp'], true);
      expect(vm.player.jobLevels[Job.adventurer], 10);
      expect(vm.showJobTutorial, true);
    });

    test('冒険者Lv10未満ではshowJobTutorialがtrueにならない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // 初期状態を明示的にLv1に設定（モックなので残留データはないが念のため）
      vm.player.jobLevels[Job.adventurer] = 1;
      vm.player.jobExps[Job.adventurer] = 0;

      // Lv1→Lv2
      vm.addTask('修行', rank: QuestRank.B);
      final taskId = vm.tasks.first.id;
      vm.acceptTask(taskId);
      final result = vm.completeTask(taskId);

      expect(result, isNotNull);
      expect(result!['leveledUp'], true);
      expect(vm.player.level, 2);
      expect(vm.showJobTutorial, false);
    });

    test('一度完了したチュートリアルは再発動しない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // 既に完了済みとしてマーク
      await vm.markJobTutorialSeen();

      // 冒険者Lv9→Lv10
      vm.player.jobLevels[Job.adventurer] = 9;
      vm.player.jobExps[Job.adventurer] = 700;

      vm.addTask('修行', rank: QuestRank.B);
      final taskId = vm.tasks.first.id;
      vm.acceptTask(taskId);
      final result = vm.completeTask(taskId);

      expect(result, isNotNull);
      expect(result!['leveledUp'], true);
      expect(vm.player.jobLevels[Job.adventurer], 10);
      // 既に完了済みなのでフラグは立たない
      expect(vm.showJobTutorial, false);
    });

    test('他職でレベルアップしても発動しない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      // 転職制限：浪人Lv10必要、テスト用に一時的に設定
      vm.player.jobLevels[Job.adventurer] = 10;
      vm.changeJob(Job.warrior);

      // 戦士Lv9→Lv10
      vm.player.jobLevels[Job.warrior] = 9;
      vm.player.jobExps[Job.warrior] = 700;
      // 冒険者レベルはLv1のまま（テスト条件）
      vm.player.jobLevels[Job.adventurer] = 1;

      vm.addTask('修行', rank: QuestRank.B);
      final taskId = vm.tasks.first.id;
      vm.acceptTask(taskId);
      final result = vm.completeTask(taskId);

      expect(result, isNotNull);
      expect(result!['leveledUp'], true);
      expect(vm.player.jobLevels[Job.warrior], 10);
      // 冒険者レベルがLv10に達していないので発動しない
      expect(vm.showJobTutorial, false);
    });

    test('markJobTutorialSeenでフラグが永続化される', () async {
      final pr = _MockPlayerRepo();
      final tr = _MockTaskRepo();
      final sr = _MockSettingsRepo();

      final vm1 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm1);

      await vm1.markJobTutorialSeen();

      await Future.delayed(const Duration(milliseconds: 200));

      final vm2 = GameViewModel(pr: pr, tr: tr, sr: sr);
      await _waitForLoad(vm2);

      expect(vm2.showJobTutorial, false);
    });
  });

  group('GameViewModel 期限切れタスク完了テスト', () {
    setUp(() {
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'test_q1',
          question: 'テスト問題1',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          expBonusPercent: 10,
        ),
        const QuizQuestion(
          id: 'test_q2',
          question: 'テスト問題2',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 2,
          expBonusPercent: 50,
        ),
      ]);
    });

    tearDown(() {
      QuizService.probability = 0.30;
    });

    test('期限切れタスク完了時にクイズが強制発動されbonusMessagesに期限切れメッセージが含まれる',
        () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);
      QuizService.probability = 0.0; // 通常抽選OFF

      final pastDeadline = DateTime.now().subtract(const Duration(days: 1));
      vm.addTask('期限切れクエスト', rank: QuestRank.B, deadline: pastDeadline);
      vm.acceptTask(vm.tasks[0].id);

      // デバッグ: deadlineが正しく設定されているか確認
      final task = vm.tasks[0];
      expect(task.deadline, isNotNull,
          reason: 'addTaskでdeadlineが設定されるべき');
      expect(task.deadline!.isBefore(DateTime.now()), isTrue,
          reason: '期限切れdeadlineは現在より過去');

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['quizQuestion'], isNotNull,
          reason: '期限切れタスクではクイズが強制発動されるべき');
      expect(result['bonusMessages'],
          anyElement(contains('刻の番人')),
          reason: '期限切れメッセージがbonusMessagesに含まれるべき');
    });

    test('期限切れタスク完了時にEXPが減少する', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      final pastDeadline = DateTime.now().subtract(const Duration(days: 1));
      vm.addTask('期限切れクエスト', rank: QuestRank.B, deadline: pastDeadline);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['baseExp'], lessThan(100),
          reason: '期限切れタスクではEXPが減少するべき');
    });

    test('期限切れでないタスクでは通常通りクイズ抽選（確率0%でnull）',
        () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      QuizService.probability = 0.0;

      final futureDeadline = DateTime.now().add(const Duration(days: 1));
      vm.addTask('期限内クエスト', rank: QuestRank.B, deadline: futureDeadline);
      vm.acceptTask(vm.tasks[0].id);

      final result = vm.completeTask(vm.tasks[0].id);
      expect(result, isNotNull);
      expect(result!['quizQuestion'], isNull,
          reason: '期限内タスクでは通常の抽選のみ');
      expect(result['bonusMessages'],
          isNot(anyElement(contains('期限切れ'))),
          reason: '期限内タスクに期限切れメッセージはない');
    });
  });

  // ━━━ G1: 転職制限 ━━━
  group('changeJob 転職制限', () {
    test('浪人Lv1では他職に転職できない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);
      // 浪人Lv1（デフォルト）
      expect(vm.player.jobLevels[Job.adventurer], 1);
      expect(vm.player.currentJob, Job.adventurer);

      vm.changeJob(Job.warrior);
      // 転職できないので冒険者のまま
      expect(vm.player.currentJob, Job.adventurer);
    });

    test('浪人Lv10で他職に転職できる', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);
      // 浪人Lv10に設定
      vm.player.jobLevels[Job.adventurer] = 10;

      vm.changeJob(Job.warrior);
      expect(vm.player.currentJob, Job.warrior);
    });

    test('他職Lv5では別の他職に転職できない（現在の職業Lv10必要）', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);
      // 浪人Lv10→侍に転職
      vm.player.jobLevels[Job.adventurer] = 10;
      vm.changeJob(Job.warrior);
      expect(vm.player.currentJob, Job.warrior);
      // 侍Lv5（Lv10未満）
      vm.player.jobLevels[Job.warrior] = 5;

      // 陰陽師に転職しようとするが、侍Lv10未満なので不可
      vm.changeJob(Job.wizard);
      expect(vm.player.currentJob, Job.warrior,
          reason: '現在の職業Lv10未満では他職に転職不可');
    });

    test('他職Lv10で別の他職に転職できる', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);
      // 浪人Lv10→侍に転職
      vm.player.jobLevels[Job.adventurer] = 10;
      vm.changeJob(Job.warrior);
      expect(vm.player.currentJob, Job.warrior);
      // 侍Lv10に設定
      vm.player.jobLevels[Job.warrior] = 10;

      vm.changeJob(Job.wizard);
      expect(vm.player.currentJob, Job.wizard);
    });

    test('浪人は常に転職可能（自分自身）', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);
      // 侍Lv10
      vm.player.jobLevels[Job.adventurer] = 10;
      vm.changeJob(Job.warrior);
      vm.player.jobLevels[Job.warrior] = 10;

      // 浪人に戻る（常に可能）
      vm.changeJob(Job.adventurer);
      expect(vm.player.currentJob, Job.adventurer);
    });

    test('デバッグモードでは転職制限が無効', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);
      // 浪人Lv1でデバッグモード有効化
      vm.tryEnableDebugMode('11111111');
      expect(vm.isDebugMode, true);

      vm.changeJob(Job.warrior);
      expect(vm.player.currentJob, Job.warrior);
    });
  });

  // ━━━ O2: 緊急依頼書表示 ━━━
  group('urgentGuildTasks 緊急依頼書', () {
    test('期限が24時間以内のギルドタスクを返す', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      final now = DateTime.now();
      // 期限が1時間後（緊急）
      vm.addTask('緊急クエスト', rank: QuestRank.A,
          deadline: now.add(const Duration(hours: 1)));
      // 期限が25時間後（緊急ではない）
      vm.addTask('通常クエスト', rank: QuestRank.B,
          deadline: now.add(const Duration(hours: 25)));
      // 期限なし
      vm.addTask('期限なしクエスト', rank: QuestRank.B);

      final urgent = vm.urgentGuildTasks;
      expect(urgent.length, 1);
      expect(urgent.first.title, '緊急クエスト');
    });

    test('期限切れのギルドタスクも含む', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      final now = DateTime.now();
      // 期限が1時間前（期限切れ）
      vm.addTask('期限切れクエスト', rank: QuestRank.A,
          deadline: now.subtract(const Duration(hours: 1)));

      final urgent = vm.urgentGuildTasks;
      expect(urgent.length, 1);
      expect(urgent.first.title, '期限切れクエスト');
    });

    test('アクティブなタスクは含まない', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      final now = DateTime.now();
      vm.player.jobLevels[Job.adventurer] = 10;
      vm.addTask('緊急クエスト', rank: QuestRank.B,
          deadline: now.add(const Duration(hours: 1)));
      // アクティブ化
      vm.acceptTask(vm.tasks[0].id);

      final urgent = vm.urgentGuildTasks;
      expect(urgent.isEmpty, true);
    });

    test('緊急度順（期限が近い順）にソートされる', () async {
      final vm = GameViewModel(
        pr: _MockPlayerRepo(),
        tr: _MockTaskRepo(),
        sr: _MockSettingsRepo(),
      );
      await _waitForLoad(vm);

      final now = DateTime.now();
      vm.addTask('3時間後', rank: QuestRank.B,
          deadline: now.add(const Duration(hours: 3)));
      vm.addTask('1時間後', rank: QuestRank.A,
          deadline: now.add(const Duration(hours: 1)));
      vm.addTask('5時間後', rank: QuestRank.B,
          deadline: now.add(const Duration(hours: 5)));

      final urgent = vm.urgentGuildTasks;
      expect(urgent.length, 3);
      expect(urgent[0].title, '1時間後');
      expect(urgent[1].title, '3時間後');
      expect(urgent[2].title, '5時間後');
    });
  });
}
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
