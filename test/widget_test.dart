// RPGTodoApp のウィジェットテスト
//
// フル起動テストは Hive + path_provider の初期化が必要なため、
// ここでは Player モデルの基本動作をスモークテストとして検証する。
// 統合テスト (integration_test) は別途整備予定。

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/models/player.dart';

void main() {
  group('Player smoke test', () {
    test('デフォルトプレイヤーは冒険者Lv1', () {
      final player = Player();
      expect(player.level, 1);
      expect(player.currentJob, Job.adventurer);
      expect(player.coins, 0);
      expect(player.gems, 0);
    });

    test('addExp でレベルアップする', () {
      final player = Player();
      // Lv1→2 には 50 EXP 必要
      final leveledUp = player.addExp(50);
      expect(leveledUp, true);
      expect(player.level, 2);
    });
  });
}
