import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/battle_state.dart';

void main() {
  group('BattleState', () {
    group('canTransitionTo', () {
      test('idle → facing のみ有効', () {
        expect(BattleState.idle.canTransitionTo(BattleState.facing), true);
        expect(BattleState.idle.canTransitionTo(BattleState.attacking), false);
        expect(BattleState.idle.canTransitionTo(BattleState.victory), false);
        expect(BattleState.idle.canTransitionTo(BattleState.defeat), false);
        expect(BattleState.idle.canTransitionTo(BattleState.idle), false);
      });

      test('facing → attacking または idle が有効', () {
        expect(BattleState.facing.canTransitionTo(BattleState.attacking), true);
        expect(BattleState.facing.canTransitionTo(BattleState.idle), true);
        expect(BattleState.facing.canTransitionTo(BattleState.victory), false);
        expect(BattleState.facing.canTransitionTo(BattleState.defeat), false);
        expect(BattleState.facing.canTransitionTo(BattleState.facing), false);
      });

      test('attacking → victory または defeat が有効', () {
        expect(BattleState.attacking.canTransitionTo(BattleState.victory), true);
        expect(BattleState.attacking.canTransitionTo(BattleState.defeat), true);
        expect(BattleState.attacking.canTransitionTo(BattleState.idle), false);
        expect(BattleState.attacking.canTransitionTo(BattleState.facing), false);
        expect(BattleState.attacking.canTransitionTo(BattleState.attacking), false);
      });

      test('victory → idle のみ有効', () {
        expect(BattleState.victory.canTransitionTo(BattleState.idle), true);
        expect(BattleState.victory.canTransitionTo(BattleState.facing), false);
        expect(BattleState.victory.canTransitionTo(BattleState.attacking), false);
        expect(BattleState.victory.canTransitionTo(BattleState.defeat), false);
        expect(BattleState.victory.canTransitionTo(BattleState.victory), false);
      });

      test('defeat → idle のみ有効', () {
        expect(BattleState.defeat.canTransitionTo(BattleState.idle), true);
        expect(BattleState.defeat.canTransitionTo(BattleState.facing), false);
        expect(BattleState.defeat.canTransitionTo(BattleState.attacking), false);
        expect(BattleState.defeat.canTransitionTo(BattleState.victory), false);
        expect(BattleState.defeat.canTransitionTo(BattleState.defeat), false);
      });
    });

    group('isInCombat', () {
      test('idle のみ false', () {
        expect(BattleState.idle.isInCombat, false);
        expect(BattleState.facing.isInCombat, true);
        expect(BattleState.attacking.isInCombat, true);
        expect(BattleState.victory.isInCombat, true);
        expect(BattleState.defeat.isInCombat, true);
      });
    });

    group('isFinished', () {
      test('victory と defeat のみ true', () {
        expect(BattleState.idle.isFinished, false);
        expect(BattleState.facing.isFinished, false);
        expect(BattleState.attacking.isFinished, false);
        expect(BattleState.victory.isFinished, true);
        expect(BattleState.defeat.isFinished, true);
      });
    });

    group('isVictory / isDefeat', () {
      test('victory のみ isVictory = true', () {
        expect(BattleState.victory.isVictory, true);
        expect(BattleState.defeat.isVictory, false);
        expect(BattleState.idle.isVictory, false);
        expect(BattleState.facing.isVictory, false);
        expect(BattleState.attacking.isVictory, false);
        expect(BattleState.victory.isDefeat, false);
        expect(BattleState.defeat.isDefeat, true);
      });
    });
  });
}
