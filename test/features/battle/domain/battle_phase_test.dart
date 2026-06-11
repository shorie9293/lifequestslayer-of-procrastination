import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';
import 'package:rpg_todo/features/battle/domain/battle_phase.dart';

void main() {
  group('BattlePhase', () {
    group('初期状態', () {
      test('初期状態は idle', () {
        final phase = BattlePhase();
        expect(phase.currentState, BattleState.idle);
        expect(phase.isInCombat, false);
        expect(phase.isFinished, false);
      });
    });

    group('正常な遷移シーケンス', () {
      test('idle → facing → attacking → victory → idle', () {
        final phase = BattlePhase();

        phase.startBattle();
        expect(phase.currentState, BattleState.facing);

        phase.selectTactic();
        expect(phase.currentState, BattleState.attacking);

        phase.declareVictory();
        expect(phase.currentState, BattleState.victory);

        phase.returnToIdle();
        expect(phase.currentState, BattleState.idle);
      });

      test('idle → facing → attacking → defeat → idle', () {
        final phase = BattlePhase();

        phase.startBattle();
        expect(phase.currentState, BattleState.facing);

        phase.selectTactic();
        expect(phase.currentState, BattleState.attacking);

        phase.declareDefeat();
        expect(phase.currentState, BattleState.defeat);

        phase.returnToIdle();
        expect(phase.currentState, BattleState.idle);
      });

      test('idle → facing → idle（対峙キャンセル）', () {
        final phase = BattlePhase();

        phase.startBattle();
        expect(phase.currentState, BattleState.facing);

        phase.cancelBattle();
        expect(phase.currentState, BattleState.idle);
      });
    });

    group('無効な遷移の例外', () {
      test('idle から facing 以外への遷移は例外', () {
        final phase = BattlePhase();
        expect(
          () => phase.selectTactic(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.declareVictory(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.declareDefeat(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.returnToIdle(),
          throwsA(isA<BattlePhaseException>()),
        );
      });

      test('facing から attacking/idle 以外への遷移は例外', () {
        final phase = BattlePhase();
        phase.startBattle();
        expect(
          () => phase.declareVictory(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.declareDefeat(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.returnToIdle(),
          throwsA(isA<BattlePhaseException>()),
        );
      });

      test('attacking から victory/defeat 以外への遷移は例外', () {
        final phase = BattlePhase();
        phase.startBattle();
        phase.selectTactic();
        expect(
          () => phase.startBattle(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.cancelBattle(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.selectTactic(),
          throwsA(isA<BattlePhaseException>()),
        );
      });

      test('victory から idle 以外への遷移は例外', () {
        final phase = BattlePhase();
        phase.startBattle();
        phase.selectTactic();
        phase.declareVictory();
        expect(
          () => phase.startBattle(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.selectTactic(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.declareVictory(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.declareDefeat(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.cancelBattle(),
          throwsA(isA<BattlePhaseException>()),
        );
      });

      test('defeat から idle 以外への遷移は例外', () {
        final phase = BattlePhase();
        phase.startBattle();
        phase.selectTactic();
        phase.declareDefeat();
        expect(
          () => phase.startBattle(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.selectTactic(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.declareVictory(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.declareDefeat(),
          throwsA(isA<BattlePhaseException>()),
        );
        expect(
          () => phase.cancelBattle(),
          throwsA(isA<BattlePhaseException>()),
        );
      });

      test('二重 startBattle は例外', () {
        final phase = BattlePhase();
        phase.startBattle();
        expect(
          () => phase.startBattle(),
          throwsA(isA<BattlePhaseException>()),
        );
      });
    });

    group('transitionTo 汎用メソッド', () {
      test('有効な遷移は成功する', () {
        final phase = BattlePhase();
        final prev = phase.transitionTo(BattleState.facing);
        expect(prev, BattleState.idle);
        expect(phase.currentState, BattleState.facing);
      });

      test('無効な遷移は例外', () {
        final phase = BattlePhase();
        expect(
          () => phase.transitionTo(BattleState.attacking),
          throwsA(isA<BattlePhaseException>()),
        );
      });
    });

    group('forceReset', () {
      test('どの状態からでも idle に戻る', () {
        for (final state in BattleState.values) {
          final phase = BattlePhase();
          // 状態を設定するための裏技的な遷移
          if (state != BattleState.idle) {
            if (state == BattleState.facing) {
              phase.startBattle();
            } else if (state == BattleState.attacking) {
              phase.startBattle();
              phase.selectTactic();
            } else if (state == BattleState.victory) {
              phase.startBattle();
              phase.selectTactic();
              phase.declareVictory();
            } else if (state == BattleState.defeat) {
              phase.startBattle();
              phase.selectTactic();
              phase.declareDefeat();
            }
          }
          expect(phase.currentState, state);
          phase.forceReset();
          expect(phase.currentState, BattleState.idle);
        }
      });
    });

    group('canTransitionTo', () {
      test('各状態の遷移可否を正しく返す', () {
        final phase = BattlePhase();
        expect(phase.canTransitionTo(BattleState.facing), true);
        expect(phase.canTransitionTo(BattleState.attacking), false);

        phase.startBattle();
        expect(phase.canTransitionTo(BattleState.attacking), true);
        expect(phase.canTransitionTo(BattleState.idle), true);

        phase.selectTactic();
        expect(phase.canTransitionTo(BattleState.victory), true);
        expect(phase.canTransitionTo(BattleState.defeat), true);
        expect(phase.canTransitionTo(BattleState.idle), false);
      });
    });

    group('BattlePhaseException', () {
      test('message に遷移情報が含まれる', () {
        const ex = BattlePhaseException(
          'test error',
          from: BattleState.idle,
          to: BattleState.attacking,
        );
        expect(ex.message, 'test error');
        expect(ex.from, BattleState.idle);
        expect(ex.to, BattleState.attacking);
        expect(ex.toString(), contains('test error'));
      });
    });
  });
}
