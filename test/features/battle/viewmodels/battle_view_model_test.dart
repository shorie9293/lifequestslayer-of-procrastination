import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/battle_phase.dart';
import 'package:rpg_todo/features/battle/domain/combo_system.dart';
import 'package:rpg_todo/features/battle/viewmodels/battle_view_model.dart';

void main() {
  /// テスト用固定時刻。
  DateTime now = DateTime(2026, 6, 7, 12, 0, 0);
  DateTime fixedClock() => now;

  /// テスト用クエスト。
  Task testTask() => Task(
        id: 'task-001',
        title: 'ゴブリンを討伐せよ',
        rank: QuestRank.B,
      );

  group('BattleViewModel', () {
    group('初期状態', () {
      test('currentState は idle', () {
        final vm = BattleViewModel();
        expect(vm.currentState, BattleState.idle);
        expect(vm.isInCombat, false);
        expect(vm.isFinished, false);
        expect(vm.currentTask, null);
        expect(vm.selectedTactic, null);
        expect(vm.lastResult, null);
      });

      test('コンボ初期値', () {
        final vm = BattleViewModel();
        expect(vm.comboCount, 0);
        expect(vm.comboMultiplier, 1.0);
        expect(vm.isComboActive, false);
      });
    });

    group('enterBattle', () {
      test('idle → facing に遷移', () {
        final vm = BattleViewModel();
        final task = testTask();
        vm.enterBattle(task);
        expect(vm.currentState, BattleState.facing);
        expect(vm.currentTask, task);
        expect(vm.isInCombat, true);
      });

      test('戦闘中に呼ぶと例外', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        expect(
          () => vm.enterBattle(testTask()),
          throwsA(isA<BattlePhaseException>()),
        );
      });
    });

    group('selectTactic', () {
      test('facing → attacking に遷移', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        expect(vm.currentState, BattleState.attacking);
        expect(vm.selectedTactic, BattleTactic.attack);
      });

      test('全戦術が設定可能', () {
        final vm = BattleViewModel();

        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.defend);
        expect(vm.selectedTactic, BattleTactic.defend);
        vm.forceReset();

        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.skill);
        expect(vm.selectedTactic, BattleTactic.skill);
      });
    });

    group('declareVictory', () {
      test('attacking → victory に遷移し、結果が返る', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);

        final result = vm.declareVictory(
          expGained: 100,
          coinsGained: 50,
          bonusMessages: ['🔥 コンボボーナス！'],
        );

        expect(vm.currentState, BattleState.victory);
        expect(result.isVictory, true);
        expect(result.expGained, 100);
        expect(result.coinsGained, 50);
        expect(result.bonusMessages, contains('🔥 コンボボーナス！'));
        expect(result.task.id, 'task-001');
      });

      test('コンボ数が増加する', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);
        expect(vm.comboCount, 1);

        // 2回目の討伐
        vm.dismissResult();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);
        expect(vm.comboCount, 2);
        expect(vm.isComboActive, true);
      });

      test('コンボボーナスEXPが含まれる', () {
        final vm = BattleViewModel();

        // 1回目: combo=1, ボーナスなし
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        var result = vm.declareVictory(expGained: 100, coinsGained: 50);
        expect(result.comboBonusExp, 0);
        vm.dismissResult();

        // 2回目: combo=2, ボーナス = 100 * 0.1 = 10
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        result = vm.declareVictory(expGained: 100, coinsGained: 50);
        expect(result.comboBonusExp, 10);
        vm.dismissResult();

        // 3回目: combo=3, ボーナス = 100 * 0.2 = 20
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        result = vm.declareVictory(expGained: 100, coinsGained: 50);
        expect(result.comboBonusExp, 20);
      });
    });

    group('declareDefeat', () {
      test('attacking → defeat に遷移し、結果が返る', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.defend);

        final result = vm.declareDefeat(
          penaltyExp: 50,
          bonusMessages: ['撤退…経験値半減'],
        );

        expect(vm.currentState, BattleState.defeat);
        expect(result.isVictory, false);
        expect(result.expGained, 0);
        expect(result.coinsGained, 0);
        expect(result.penaltyExp, 50);
      });

      test('敗北ではコンボ数は増加しない', () {
        final vm = BattleViewModel();

        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);
        expect(vm.comboCount, 1);

        vm.dismissResult();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.defend);
        vm.declareDefeat(penaltyExp: 30);
        expect(vm.comboCount, 1); // 変わらない
      });
    });

    group('dismissResult', () {
      test('victory → idle', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);

        vm.dismissResult();
        expect(vm.currentState, BattleState.idle);
        expect(vm.currentTask, null);
        expect(vm.selectedTactic, null);
        // lastResult はクリアされない（UI表示後も参照可能）
      });

      test('defeat → idle', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.defend);
        vm.declareDefeat(penaltyExp: 30);

        vm.dismissResult();
        expect(vm.currentState, BattleState.idle);
      });
    });

    group('cancelBattle', () {
      test('facing → idle', () {
        final vm = BattleViewModel();
        vm.enterBattle(testTask());
        vm.cancelBattle();
        expect(vm.currentState, BattleState.idle);
        expect(vm.currentTask, null);
      });
    });

    group('forceReset', () {
      test('どの状態からでも idle に戻る', () {
        final vm = BattleViewModel();
        vm.forceReset();
        expect(vm.currentState, BattleState.idle);

        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);
        vm.forceReset();
        expect(vm.currentState, BattleState.idle);
      });
    });

    group('resetCombo', () {
      test('コンボを強制リセット', () {
        final vm = BattleViewModel();

        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);
        vm.dismissResult();

        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);
        vm.dismissResult();

        vm.enterBattle(testTask());
        vm.selectTactic(BattleTactic.attack);
        vm.declareVictory(expGained: 100, coinsGained: 50);

        expect(vm.comboCount, 3);
        vm.resetCombo();
        expect(vm.comboCount, 0);
        expect(vm.comboMultiplier, 1.0);
      });
    });

    group('カスタム ComboSystem', () {
      test('外部から ComboSystem を注入可能', () {
        final combo = ComboSystem(
          clock: fixedClock,
          multiplierStep: 0.2,
          maxMultiplier: 4.0,
        );
        combo.onVictory();
        combo.onVictory();
        // multiplier = 1.0 + (2-1)*0.2 = 1.2

        final vm = BattleViewModel(combo: combo);
        expect(vm.comboCount, 2);
        expect(vm.comboMultiplier, 1.2);
      });
    });

    group('change notification', () {
      test('状態遷移で notifyListeners が発火する', () {
        final vm = BattleViewModel();
        int notifyCount = 0;
        vm.addListener(() => notifyCount++);

        vm.enterBattle(testTask());
        expect(notifyCount, 1);

        vm.selectTactic(BattleTactic.attack);
        expect(notifyCount, 2);

        vm.declareVictory(expGained: 100, coinsGained: 50);
        expect(notifyCount, 3);

        vm.dismissResult();
        expect(notifyCount, 4);
      });
    });
  });

  group('BattleTactic', () {
    test('3つの戦術が定義されている', () {
      expect(BattleTactic.values.length, 3);
      expect(BattleTactic.values, contains(BattleTactic.attack));
      expect(BattleTactic.values, contains(BattleTactic.defend));
      expect(BattleTactic.values, contains(BattleTactic.skill));
    });
  });

  group('BattleResult', () {
    test('全フィールドが正しく設定される', () {
      final task = testTask();
      final result = BattleResult(
        isVictory: true,
        task: task,
        expGained: 100,
        coinsGained: 50,
        comboBonusExp: 20,
        comboCount: 3,
        comboMultiplier: 1.2,
        bonusMessages: ['🔥 ボーナス'],
      );
      expect(result.isVictory, true);
      expect(result.task, task);
      expect(result.expGained, 100);
      expect(result.coinsGained, 50);
      expect(result.comboBonusExp, 20);
      expect(result.comboCount, 3);
      expect(result.comboMultiplier, 1.2);
      expect(result.bonusMessages, ['🔥 ボーナス']);
      expect(result.penaltyExp, null);
    });

    test('敗北結果のフィールド', () {
      final task = testTask();
      final result = BattleResult(
        isVictory: false,
        task: task,
        expGained: 0,
        coinsGained: 0,
        comboBonusExp: 0,
        comboCount: 1,
        comboMultiplier: 1.0,
        penaltyExp: 50,
      );
      expect(result.isVictory, false);
      expect(result.expGained, 0);
      expect(result.penaltyExp, 50);
    });
  });
}
