import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/services/title_service.dart';
import 'package:rpg_todo/models/player.dart';
import 'package:rpg_todo/models/title_definition.dart';

void main() {
  group('TitleService', () {
    test('getTitleProgressList - 初期状態ですべての称号進捗が0', () {
      final player = Player();
      final progress = TitleService.getTitleProgressList(player);
      expect(progress.length, kAllTitles.length);
      for (final p in progress) {
        expect(p.progress, 0);
      }
    });

    test('getTitleProgressList - タスク完了数が反映される', () {
      final player = Player()..totalTasksCompleted = 10;
      // checkTitles を呼んで称号を実際に獲得させる
      TitleService.checkTitles(player, []);
      final progress = TitleService.getTitleProgressList(player);
      // 「見習い冒険者」は完了タスク10で獲得
      final beginnerTitle = progress.firstWhere((p) => p.def.id == '見習い冒険者');
      expect(beginnerTitle.progress, 10);
      expect(beginnerTitle.isUnlocked, true);
    });

    test('checkTitles - 条件を満たす称号を獲得する', () {
      final player = Player()..totalTasksCompleted = 100;
      final messages = <String>[];
      TitleService.checkTitles(player, messages);
      // 100タスク完了で「ベテラン」を獲得
      expect(player.titles.contains('ベテラン'), true);
      expect(messages.any((m) => m.contains('ベテラン')), true);
    });

    test('checkTitles - 既に獲得済みの称号は重複して獲得しない', () {
      final player = Player()
        ..totalTasksCompleted = 100
        ..titles = ['ベテラン'];
      final messages = <String>[];
      TitleService.checkTitles(player, messages);
      // 既に獲得済みなので新たなメッセージは追加されない
      expect(messages.any((m) => m.contains('ベテラン')), false);
    });
  });
}
