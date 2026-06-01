import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

void main() {
  group('ShopViewModel', () {
    test('spendGems returns false when balance insufficient', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      final shopVm = ShopViewModel(playerVm);
      expect(shopVm.spendGems(10), isFalse);
    });

    test('spendGems returns true and decreases gems when sufficient', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      playerVm.addGems(50);
      final shopVm = ShopViewModel(playerVm);
      expect(shopVm.spendGems(30), isTrue);
      expect(playerVm.player.gems, 20);
    });

    test('resetFatigueWithGems debugMode', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      playerVm.setDailyTasksCompleted(5);
      final shopVm = ShopViewModel(playerVm);
      expect(shopVm.resetFatigueWithGems(debugMode: true), isTrue);
      expect(playerVm.player.dailyTasksCompleted, 0);
    });
  });
}
