import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/features/town/domain/building.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';

/// Hive非依存のインメモリ PlayerRepository モック
class _MockPlayerRepo implements IPlayerRepository {
  @override
  bool get loadFailedDueToCorruption => false;
  Player _player = Player();
  @override
  Future<Player?> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player player) async => _player = player;
  @override
  Future<void> close() async {}
}

late Box<dynamic> _testBox;

void main() {
  setUp(() async {
    Hive.init('test/hive_testing_path');
    _testBox = await Hive.openBox<dynamic>('townBox_test');
    await _testBox.clear();
  });

  tearDown(() async {
    await _testBox.close();
  });

  group('TownViewModel initialization', () {
    test('initializes with default town level 1', () {
      final viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
      expect(viewModel.townLevel.level, equals(1));
      expect(viewModel.townLevel.xp, equals(0));
    });

    test('initializes all 4 buildings at level 1', () {
      final viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
      expect(viewModel.buildings.length, equals(4));
      for (final building in Building.values) {
        final state = viewModel.buildings[building];
        expect(state, isNotNull);
        expect(state!.level, equals(1));
      }
    });

    test('townScale returns wildernessCamp at town level 1', () {
      final viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
      expect(viewModel.townScale, equals(TownScale.wildernessCamp));
    });
  });

  group('addTownXp', () {
    late TownViewModel viewModel;

    setUp(() {
      viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
    });

    test('adds XP to town level', () {
      final oldXp = viewModel.townLevel.xp;
      viewModel.addTownXp(10);
      expect(viewModel.townLevel.xp, equals(oldXp + 10));
    });

    test('notifies listeners when XP is added', () {
      bool notified = false;
      viewModel.addListener(() => notified = true);
      viewModel.addTownXp(10);
      expect(notified, isTrue);
    });

    test('returns true when town levels up', () {
      final needed = viewModel.townLevel.xpToNext;
      final result = viewModel.addTownXp(needed);
      expect(result, isTrue);
      expect(viewModel.townLevel.level, greaterThan(1));
    });

    test('returns false when not enough XP for level up', () {
      final needed = viewModel.townLevel.xpToNext;
      final result = viewModel.addTownXp(needed - 1);
      expect(result, isFalse);
    });
  });

  group('upgradeBuilding', () {
    late TownViewModel viewModel;
    late _MockPlayerRepo playerRepo;

    setUp(() {
      viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
      playerRepo = _MockPlayerRepo();
      playerRepo.savePlayer(Player(coins: 1000));
    });

    test('upgrades building and deducts coins', () async {
      final player = (await playerRepo.loadPlayer())!;
      final result = viewModel.upgradeBuilding(
        Building.inn,
        playerCoins: player.coins,
        spendCoins: (amount) {
          player.coins -= amount;
        },
      );
      expect(result, isTrue);
      expect(viewModel.buildings[Building.inn]!.level, equals(2));
    });

    test('fails when not enough coins', () async {
      final player = (await playerRepo.loadPlayer())!;
      player.coins = 5;
      final result = viewModel.upgradeBuilding(
        Building.inn,
        playerCoins: player.coins,
        spendCoins: (amount) {},
      );
      expect(result, isFalse);
      expect(viewModel.buildings[Building.inn]!.level, equals(1));
    });

    test('fails at max building level', () async {
      final player = (await playerRepo.loadPlayer())!;
      viewModel.buildings[Building.inn]!.level = 5;
      final result = viewModel.upgradeBuilding(
        Building.inn,
        playerCoins: player.coins,
        spendCoins: (amount) {},
      );
      expect(result, isFalse);
    });

    test('notifies listeners on successful upgrade', () async {
      final player = (await playerRepo.loadPlayer())!;
      bool notified = false;
      viewModel.addListener(() => notified = true);
      viewModel.upgradeBuilding(
        Building.inn,
        playerCoins: player.coins,
        spendCoins: (amount) {
          player.coins -= amount;
        },
      );
      expect(notified, isTrue);
    });
  });

  group('persistence', () {
    test('save and load preserves town level and buildings', () async {
      final viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
      viewModel.addTownXp(500);
      await viewModel.save();

      // Load into new VM
      final newVM = TownViewModel();
      newVM.boxForTest = _testBox;
      await newVM.load();
      newVM.initialize();

      expect(newVM.townLevel.level, equals(viewModel.townLevel.level));
      expect(newVM.townLevel.xp, equals(viewModel.townLevel.xp));
    });

    test('load with no stored data uses defaults', () async {
      final viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
      await viewModel.load();
      expect(viewModel.townLevel.level, equals(1));
    });
  });

  group('town scale integration', () {
    test('townScale changes when town level crosses thresholds', () {
      final viewModel = TownViewModel();
      viewModel.boxForTest = _testBox;
      viewModel.initialize();
      expect(viewModel.townScale, equals(TownScale.wildernessCamp));

      while (viewModel.townLevel.level < 11) {
        viewModel.addTownXp(viewModel.townLevel.xpToNext);
      }
      expect(viewModel.townScale, equals(TownScale.smallSettlement));
    });
  });
}
