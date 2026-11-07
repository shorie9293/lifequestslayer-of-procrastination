import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/domain/battle_tactic.dart';
import 'package:rpg_todo/features/battle/domain/battle_outcome_calculator.dart';

void main() {
  group('BattleOutcomeCalculator — 戦術→報酬補正の表引き', () {
    test('戦術未選択（null）は補正なし（1.0倍・1.0倍）', () {
      final effect = BattleOutcomeCalculator.effectFor(null);
      expect(effect.expMultiplier, 1.0);
      expect(effect.coinMultiplier, 1.0);
    });

    test('攻撃は標準（1.0倍・1.0倍）', () {
      final effect = BattleOutcomeCalculator.effectFor(BattleTactic.attack);
      expect(effect.expMultiplier, 1.0);
      expect(effect.coinMultiplier, 1.0);
    });

    test('防御はEXP控えめ・コイン多め', () {
      final effect = BattleOutcomeCalculator.effectFor(BattleTactic.defend);
      expect(effect.expMultiplier, lessThan(1.0));
      expect(effect.coinMultiplier, greaterThan(1.0));
    });

    test('スキルはEXP多め・コイン控えめ', () {
      final effect = BattleOutcomeCalculator.effectFor(BattleTactic.skill);
      expect(effect.expMultiplier, greaterThan(1.0));
      expect(effect.coinMultiplier, lessThan(1.0));
    });

    test('同じ基礎値でも戦術が違えばEXPが異なる（3択が装飾でない）', () {
      const base = 100;
      final attack = BattleOutcomeCalculator.expFor(base, BattleTactic.attack);
      final defend = BattleOutcomeCalculator.expFor(base, BattleTactic.defend);
      final skill = BattleOutcomeCalculator.expFor(base, BattleTactic.skill);
      expect({attack, defend, skill}.length, 3);
    });

    test('同じ基礎値でも戦術が違えばコインが異なる（3択が装飾でない）', () {
      const base = 100;
      final attack = BattleOutcomeCalculator.coinsFor(base, BattleTactic.attack);
      final defend = BattleOutcomeCalculator.coinsFor(base, BattleTactic.defend);
      final skill = BattleOutcomeCalculator.coinsFor(base, BattleTactic.skill);
      expect({attack, defend, skill}.length, 3);
    });

    test('Bランク相当（EXP100/コイン10）の具体値', () {
      expect(BattleOutcomeCalculator.expFor(100, BattleTactic.attack), 100);
      expect(BattleOutcomeCalculator.expFor(100, BattleTactic.defend), 70);
      expect(BattleOutcomeCalculator.expFor(100, BattleTactic.skill), 130);
      expect(BattleOutcomeCalculator.coinsFor(10, BattleTactic.attack), 10);
      expect(BattleOutcomeCalculator.coinsFor(10, BattleTactic.defend), 15);
      expect(BattleOutcomeCalculator.coinsFor(10, BattleTactic.skill), 8);
    });

    test('丸めは四捨五入し、基礎値0は0のまま・負値は0にクランプ', () {
      expect(BattleOutcomeCalculator.expFor(0, BattleTactic.defend), 0);
      expect(BattleOutcomeCalculator.coinsFor(0, BattleTactic.skill), 0);
      expect(BattleOutcomeCalculator.expFor(-50, BattleTactic.skill), 0);
      expect(BattleOutcomeCalculator.coinsFor(-10, BattleTactic.defend), 0);
      // 5 * 0.7 = 3.5 → 4（四捨五入）
      expect(BattleOutcomeCalculator.expFor(5, BattleTactic.defend), 4);
      // 5 * 1.3 = 6.5 → 7（四捨五入）
      expect(BattleOutcomeCalculator.expFor(5, BattleTactic.skill), 7);
    });

    test('基礎値が大きいほど結果も大きい（単調性）', () {
      for (final tactic in BattleTactic.values) {
        final small = BattleOutcomeCalculator.expFor(100, tactic);
        final large = BattleOutcomeCalculator.expFor(1000, tactic);
        expect(large, greaterThan(small), reason: '$tactic');
      }
    });

    test('effectFor は各戦術に説明メッセージを持つ', () {
      for (final tactic in BattleTactic.values) {
        final effect = BattleOutcomeCalculator.effectFor(tactic);
        expect(effect.message, isNotEmpty, reason: '$tactic');
      }
      expect(BattleOutcomeCalculator.effectFor(null).message, isEmpty);
    });
  });
}
