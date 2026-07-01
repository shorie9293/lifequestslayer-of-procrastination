import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/battle/domain/battle_action.dart';

void main() {
  group('BattleAction.description', () {
    test('attack: 標準ダメージ表記が含まれている', () {
      final desc = BattleAction.attack.description;
      expect(desc, contains('標準ダメージ'));
    });

    test('defend: 「成功率」ではなく具体的な「討伐成功率」表記が含まれている', () {
      final desc = BattleAction.defend.description;
      // 「成功率↑」ではなく「討伐成功率↑」という具体的な表記
      expect(desc, contains('討伐成功率↑'));
      // 旧来の「成功率↑」単体（「討伐」のprefixなし）は出現しない
      expect(desc, isNot(contains(RegExp(r'(?<!討伐)成功率↑'))));
    });

    test('defend: 経験値減少が「経験値↓」で表記されている', () {
      final desc = BattleAction.defend.description;
      expect(desc, contains('経験値↓'));
    });

    test('skill: 説明が空でない', () {
      expect(BattleAction.skill.description, isNotEmpty);
    });
  });

  group('BattleAction.label', () {
    test('攻撃/防御/スキルのラベルが正しい', () {
      expect(BattleAction.attack.label, '攻撃');
      expect(BattleAction.defend.label, '防御');
      expect(BattleAction.skill.label, 'スキル');
    });
  });

  group('BattleAction.emoji', () {
    test('絵文字が正しい', () {
      expect(BattleAction.attack.emoji, '⚔️');
      expect(BattleAction.defend.emoji, '🛡️');
      expect(BattleAction.skill.emoji, '✨');
    });
  });
}
