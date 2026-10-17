import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/town/domain/town_event_reward.dart';

void main() {
  group('TownEventReward.fromMap', () {
    test('null は空報酬', () {
      final reward = TownEventReward.fromMap(null);
      expect(reward.isEmpty, isTrue);
      expect(reward.xp, 0);
      expect(reward.gems, 0);
      expect(reward.hint, isNull);
      expect(reward.label, isEmpty);
    });

    test('xp / gems / hint を解釈する', () {
      final reward = TownEventReward.fromMap(
          const {'xp': 50, 'gems': 3, 'hint': '深夜の討伐に隠された力あり'});
      expect(reward.xp, 50);
      expect(reward.gems, 3);
      expect(reward.hint, '深夜の討伐に隠された力あり');
      expect(reward.label, 'EXP +50 / ジェム +3 / ヒント: 深夜の討伐に隠された力あり');
    });

    test('負値は 0 に丸める（報酬で減らさない）', () {
      final reward = TownEventReward.fromMap(const {'xp': -40, 'gems': -2});
      expect(reward.xp, 0);
      expect(reward.gems, 0);
      expect(reward.isEmpty, isTrue);
    });

    test('型揺れ（num / String）を吸収する', () {
      final reward = TownEventReward.fromMap(const {'xp': 12.9, 'gems': '7'});
      expect(reward.xp, 12);
      expect(reward.gems, 7);
    });

    test('解釈不能な型・未知キーは無視する', () {
      final reward = TownEventReward.fromMap(const {
        'xp': 'たくさん',
        'gems': null,
        'unknown_reward': 999,
      });
      expect(reward.isEmpty, isTrue);
    });

    test('空文字のヒントは null に正規化する', () {
      final reward = TownEventReward.fromMap(const {'hint': '   '});
      expect(reward.hint, isNull);
      expect(reward.isEmpty, isTrue);
    });

    test('疲労回復は値として保持するが label には含めない（未接続の報酬を付与扱いしない）', () {
      final reward = TownEventReward.fromMap(const {'fatigue_recovery': 1});
      expect(reward.fatigueRecovery, 1);
      expect(reward.label, isEmpty);
    });
  });

  group('既存イベント定義の報酬が型付きで解釈できる', () {
    test('旅の商人 = xp50 / gems3', () {
      final reward = TownEventReward.fromMap(
          const {'xp': 50, 'gems': 3});
      expect(reward.label, 'EXP +50 / ジェム +3');
    });
  });
}
