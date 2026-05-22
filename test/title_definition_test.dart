import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';

void main() {
  group('kAllTitles', () {
    test('5つの称号定義が登録されている', () {
      expect(kAllTitles.length, 5);
    });

    test('称号一覧が期待通り', () {
      final ids = kAllTitles.map((t) => t.id).toList();
      expect(ids, [
        '見習い冒険者',
        'ベテラン',
        '鬼退治',
        '大物祓い',
        '龍神討ち',
      ]);
    });
  });

  group('TitleDefinition.getProgress', () {
    test('初期状態では全称号の進捗が0', () {
      final player = Player();
      for (final def in kAllTitles) {
        expect(def.getProgress(player), 0);
      }
    });

    test('「見習い冒険者」は totalTasksCompleted を参照する', () {
      final player = Player()..totalTasksCompleted = 7;
      final def = kAllTitles.firstWhere((d) => d.id == '見習い冒険者');
      expect(def.getProgress(player), 7);
      expect(def.requiredCount, 10);
    });

    test('「ベテラン」は totalTasksCompleted=100 で達成', () {
      final player = Player()..totalTasksCompleted = 100;
      final def = kAllTitles.firstWhere((d) => d.id == 'ベテラン');
      expect(def.getProgress(player), 100);
      expect(def.requiredCount, 100);
    });

    test('「鬼退治」は totalBRankCompleted を参照する', () {
      final player = Player()..totalBRankCompleted = 30;
      final def = kAllTitles.firstWhere((d) => d.id == '鬼退治');
      expect(def.getProgress(player), 30);
      expect(def.requiredCount, 50);
    });

    test('「大物祓い」は totalARankCompleted を参照する', () {
      final player = Player()..totalARankCompleted = 20;
      final def = kAllTitles.firstWhere((d) => d.id == '大物祓い');
      expect(def.getProgress(player), 20);
      expect(def.requiredCount, 20);
    });

    test('「龍神討ち」は totalSRankCompleted を参照する', () {
      final player = Player()..totalSRankCompleted = 5;
      final def = kAllTitles.firstWhere((d) => d.id == '龍神討ち');
      expect(def.getProgress(player), 5);
      expect(def.requiredCount, 5);
    });
  });
}
