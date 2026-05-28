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

  group('equipSkill / unequipSkill', () {
    test('equipSkill adds skill to equippedSkills', () async {
      await vm.load();
      vm.equipSkill(JobSkill.warriorCombo);
      expect(
        vm.player.equippedSkills.any((es) => es.skill == JobSkill.warriorCombo),
        isTrue,
      );
    });

    test('equipSkill respects slot limit', () async {
      await vm.load();
      // Player starts with Lv1 adventurer → 1 slot
      vm.equipSkill(JobSkill.clericRepeatAfter); // 1st slot - ok
      vm.equipSkill(JobSkill.wizardSubtask); // 2nd slot - should fail (only 1)
      expect(vm.player.equippedSkills.length, 1);
    });

    test('equipSkill does not double-add same skill', () async {
      await vm.load();
      vm.equipSkill(JobSkill.warriorCombo);
      vm.equipSkill(JobSkill.warriorCombo);
      final count = vm.player.equippedSkills
          .where((es) => es.skill == JobSkill.warriorCombo)
          .length;
      expect(count, 1);
    });

    test('unequipSkill removes skill at slotIndex', () async {
      await vm.load();
      vm.equipSkill(JobSkill.warriorCombo);
      vm.unequipSkill(0);
      expect(vm.player.equippedSkills.length, 0);
    });

    test('unequipSkill with out-of-range index does nothing', () async {
      await vm.load();
      vm.equipSkill(JobSkill.warriorCombo);
      vm.unequipSkill(5); // out of range
      expect(vm.player.equippedSkills.length, 1);
    });

    test('Adventurer mastered (Lv10+) gives 2 slots', () async {
      await vm.load();
      vm.changeJob(Job.adventurer, debugMode: true);
      // Set adventurer to Lv10
      final p = vm.player;
      p.jobLevels[Job.adventurer] = 10;
      // Manually notify
      vm.equipSkill(JobSkill.warriorCombo); // slot 1
      vm.equipSkill(JobSkill.clericRepeatAfter); // slot 2 - should work now
      expect(vm.player.equippedSkills.length, 2);
    });
  });
}
