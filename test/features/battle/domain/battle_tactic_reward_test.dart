import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/battle/domain/battle_tactic.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';

/// レアドロップを必ず外す乱数（確率的時限爆弾の回避）。
class _NoRareDropRandom implements Random {
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  late TaskCompletionService service;

  setUp(() {
    service = TaskCompletionService(rng: _NoRareDropRandom());
    QuizService.probability = 0.0; // クイズ抽選を外して報酬計算だけを見る
  });

  tearDown(() {
    QuizService.probability = 0.30;
  });

  Task makeTask(String id, {QuestRank rank = QuestRank.B}) => Task(
        id: id,
        title: '戦術テスト用クエスト',
        status: TaskStatus.active,
        rank: rank,
      );

  TaskCompletionResult complete(BattleTactic? tactic, {String id = 'q1'}) {
    return service.complete(
      task: makeTask(id),
      player: Player(),
      hasShownFatiguePopupToday: false,
      knowledgeQuestEnabled: false,
      tactic: tactic,
    )!;
  }

  group('TaskCompletionService — 戦術が討伐結果に作用する', () {
    test('戦術未指定は従来通り（後方互換: Bランク EXP100/コイン10）', () {
      final result = complete(null);
      expect(result.expGain, 100);
      expect(result.coinsGained, 10);
    });

    test('攻撃は戦術未指定と同一（標準）', () {
      final none = complete(null, id: 'a');
      final attack = complete(BattleTactic.attack, id: 'b');
      expect(attack.expGain, none.expGain);
      expect(attack.coinsGained, none.coinsGained);
    });

    test('同一入力でtacticだけ変えるとEXPが3通りに分かれる', () {
      final attack = complete(BattleTactic.attack, id: 'a');
      final defend = complete(BattleTactic.defend, id: 'b');
      final skill = complete(BattleTactic.skill, id: 'c');
      expect({attack.expGain, defend.expGain, skill.expGain}.length, 3);
      expect(defend.expGain, lessThan(attack.expGain));
      expect(skill.expGain, greaterThan(attack.expGain));
    });

    test('同一入力でtacticだけ変えるとコインが3通りに分かれる', () {
      final attack = complete(BattleTactic.attack, id: 'a');
      final defend = complete(BattleTactic.defend, id: 'b');
      final skill = complete(BattleTactic.skill, id: 'c');
      expect({attack.coinsGained, defend.coinsGained, skill.coinsGained}.length, 3);
      expect(defend.coinsGained, greaterThan(attack.coinsGained));
      expect(skill.coinsGained, lessThan(attack.coinsGained));
    });

    test('戦術の効果はプレイヤーの実残高にも反映される（表示だけでない）', () {
      final attack = complete(BattleTactic.attack, id: 'a');
      final skill = complete(BattleTactic.skill, id: 'b');
      expect(skill.updatedPlayer.coins, greaterThan(0));
      // EXPは獲得量が異なるため、レベル・累積EXPのいずれかに差が出る
      final attackTotal =
          attack.updatedPlayer.currentExp + attack.updatedPlayer.level * 100000;
      final skillTotal =
          skill.updatedPlayer.currentExp + skill.updatedPlayer.level * 100000;
      expect(skillTotal, greaterThan(attackTotal));
    });

    test('戦術を選ぶと説明メッセージが討伐結果に載る', () {
      final defend = complete(BattleTactic.defend);
      expect(
        defend.bonusMessages.any((m) => m.contains('防御')),
        isTrue,
        reason: 'bonusMessages=${defend.bonusMessages}',
      );
      // 未指定時はメッセージを増やさない（後方互換）
      final none = complete(null, id: 'z');
      expect(none.bonusMessages.any((m) => m.contains('の型')), isFalse);
    });
  });
}
