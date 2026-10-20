import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/streak_freeze/data/streak_freeze_repository.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';

void main() {
  group('InMemoryStreakFreezeRepository', () {
    test('未保存なら既定（券0枚）', () async {
      final repo = InMemoryStreakFreezeRepository();
      final state = await repo.load();
      expect(state, StreakFreezeState.defaults);
      expect(repo.saveCount, 0);
    });

    test('保存した内容が読み戻せる', () async {
      final repo = InMemoryStreakFreezeRepository();
      const state = StreakFreezeState(tickets: 2, grantedMilestones: [7]);
      await repo.save(state);
      expect(await repo.load(), state);
      expect(repo.saveCount, 1);
    });

    test('初期値を注入できる', () async {
      final repo = InMemoryStreakFreezeRepository(
          const StreakFreezeState(tickets: 1));
      expect((await repo.load()).tickets, 1);
    });
  });

  group('HiveStreakFreezeRepository', () {
    test('box/key 名はプレイヤー本体と独立している', () {
      expect(HiveStreakFreezeRepository.boxName, 'streak_freeze_box');
      expect(HiveStreakFreezeRepository.keyName, 'state');
    });
  });
}
