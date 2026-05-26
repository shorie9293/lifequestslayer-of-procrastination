import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

void main() {
  late PlayerViewModel vm;
  setUp(() {
    vm = PlayerViewModel(_MockPlayerRepo());
  });

  test('addExp increases experience', () async {
    await vm.load();
    vm.addExp(10);
    expect(vm.player.currentExp, 10);
  });

  test('addGems increases gems', () async {
    await vm.load();
    vm.addGems(50);
    expect(vm.player.gems, 50);
  });

  test('spendCoins decreases coins after adding', () async {
    await vm.load();
    vm.addCoins(100);
    vm.spendCoins(30);
    expect(vm.player.coins, 70);
  });

  test('changeJob respects debugMode', () async {
    await vm.load();
    vm.changeJob(Job.warrior, debugMode: true);
    expect(vm.player.currentJob, Job.warrior);
  });
}
