import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';

void main() {
  group('kAllTitles', () {
    test('9つの称号定義が登録されている', () {
      expect(kAllTitles.length, 9);
    });

    test('称号一覧が期待通り', () {
      final ids = kAllTitles.map((t) => t.id).toList();
      expect(ids, [
        '見習い冒険者',
        'ベテラン',
        '鬼退治',
        '大物祓い',
        '龍神討ち',
        '刻の番人を討ちし者',
        '月を跨ぎし者',
        '継続の達人',
        '時の支配者',
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

    test('「刻の番人を討ちし者」は timesWardenDefeated を参照する', () {
      final player = Player()..timesWardenDefeated = 1;
      final def = kAllTitles.firstWhere((d) => d.id == '刻の番人を討ちし者');
      expect(def.getProgress(player), 1);
      expect(def.requiredCount, 1);
    });

    group('ストリーク称号（UX-10）', () {
      test('「月を跨ぎし者」は streakDays を参照する（30日で達成）', () {
        final player = Player()..streakDays = 30;
        final def = kAllTitles.firstWhere((d) => d.id == '月を跨ぎし者');
        expect(def.getProgress(player), 30);
        expect(def.requiredCount, 30);
      });

      test('「継続の達人」は streakDays を参照する（60日で達成）', () {
        final player = Player()..streakDays = 60;
        final def = kAllTitles.firstWhere((d) => d.id == '継続の達人');
        expect(def.getProgress(player), 60);
        expect(def.requiredCount, 60);
      });

      test('「時の支配者」は streakDays を参照する（100日で達成）', () {
        final player = Player()..streakDays = 100;
        final def = kAllTitles.firstWhere((d) => d.id == '時の支配者');
        expect(def.getProgress(player), 100);
        expect(def.requiredCount, 100);
      });
    });
  });
}
