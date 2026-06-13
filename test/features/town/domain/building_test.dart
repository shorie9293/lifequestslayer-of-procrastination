import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/town/domain/building.dart';

void main() {
  group('Building enum', () {
    test('has four building types', () {
      expect(Building.values.length, equals(4));
      expect(Building.values, contains(Building.inn));
      expect(Building.values, contains(Building.shop));
      expect(Building.values, contains(Building.blacksmith));
      expect(Building.values, contains(Building.watchtower));
    });

    test('each building has a displayName', () {
      expect(Building.inn.displayName, isNotEmpty);
      expect(Building.shop.displayName, isNotEmpty);
      expect(Building.blacksmith.displayName, isNotEmpty);
      expect(Building.watchtower.displayName, isNotEmpty);
    });

    test('each building has correct unlock town level', () {
      expect(Building.inn.unlockTownLevel, equals(1));
      expect(Building.shop.unlockTownLevel, equals(3));
      expect(Building.blacksmith.unlockTownLevel, equals(7));
      expect(Building.watchtower.unlockTownLevel, equals(12));
    });
  });

  group('BuildingState', () {
    test('creates with default level 1', () {
      final state = BuildingState(building: Building.inn);
      expect(state.building, equals(Building.inn));
      expect(state.level, equals(1));
    });

    test('maxLevel is 5', () {
      final state = BuildingState(building: Building.inn);
      expect(state.level, lessThanOrEqualTo(BuildingState.maxLevel));
    });

    test('isUnlocked checks town level against unlock level', () {
      final inn = BuildingState(building: Building.inn);
      expect(inn.isUnlocked(0), isFalse);  // inn needs Lv.1
      expect(inn.isUnlocked(1), isTrue);

      final smith = BuildingState(building: Building.blacksmith);
      expect(smith.isUnlocked(6), isFalse); // blacksmith needs Lv.7
      expect(smith.isUnlocked(7), isTrue);
    });

    test('upgradeCoinCost increases with level', () {
      final state = BuildingState(building: Building.inn, level: 1);
      expect(state.upgradeCoinCost, equals(100)); // level 1 * 100

      final state3 = BuildingState(building: Building.inn, level: 3);
      expect(state3.upgradeCoinCost, equals(300)); // level 3 * 100
    });

    test('canUpgrade returns false at max level', () {
      final state = BuildingState(building: Building.inn, level: 5);
      expect(state.canUpgrade, isFalse);
    });

    test('canUpgrade returns true below max level', () {
      final state = BuildingState(building: Building.inn, level: 2);
      expect(state.canUpgrade, isTrue);
    });

    test('upgrade increments level', () {
      final state = BuildingState(building: Building.inn, level: 2);
      final result = state.upgrade();
      expect(result, isTrue);
      expect(state.level, equals(3));
    });

    test('upgrade fails at max level', () {
      final state = BuildingState(building: Building.inn, level: 5);
      final result = state.upgrade();
      expect(result, isFalse);
      expect(state.level, equals(5));
    });

    test('toJson/fromJson roundtrip', () {
      final original = BuildingState(building: Building.shop, level: 3);
      final json = original.toJson();
      final restored = BuildingState.fromJson(json);
      expect(restored.building, equals(original.building));
      expect(restored.level, equals(original.level));
    });

    test('fromJson with missing level defaults to 1', () {
      final state = BuildingState.fromJson({'building': 'blacksmith'});
      expect(state.building, equals(Building.blacksmith));
      expect(state.level, equals(1));
    });

    test('getEffect returns non-empty description for each building', () {
      for (final building in Building.values) {
        final state = BuildingState(building: building, level: 1);
        expect(state.getEffect(), isNotEmpty);
      }
    });
  });
}
