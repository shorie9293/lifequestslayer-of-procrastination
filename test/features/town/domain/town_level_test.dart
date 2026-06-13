import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/town/domain/town_level.dart';

void main() {
  group('TownLevel', () {
    group('constructor', () {
      test('default town starts at level 1 with 0 XP', () {
        final town = TownLevel();
        expect(town.level, equals(1));
        expect(town.xp, equals(0));
      });

      test('can construct with custom level and xp', () {
        final town = TownLevel(level: 5, xp: 200);
        expect(town.level, equals(5));
        expect(town.xp, equals(200));
      });
    });

    group('xpToNext', () {
      test('returns required XP for next level', () {
        final town = TownLevel(level: 1);
        expect(town.xpToNext, greaterThan(0));
      });

      test('increases with level', () {
        final town1 = TownLevel(level: 1);
        final town10 = TownLevel(level: 10);
        expect(town10.xpToNext, greaterThan(town1.xpToNext));
      });
    });

    group('addXp', () {
      test('adds XP and returns false when not enough to level up', () {
        final town = TownLevel(level: 1, xp: 0);
        final needed = town.xpToNext;
        final leveledUp = town.addXp(needed - 1);
        expect(leveledUp, isFalse);
        expect(town.level, equals(1));
        expect(town.xp, equals(needed - 1));
      });

      test('levels up and returns true when XP threshold met', () {
        final town = TownLevel(level: 1, xp: 0);
        final needed = town.xpToNext;
        final leveledUp = town.addXp(needed);
        expect(leveledUp, isTrue);
        expect(town.level, equals(2));
        expect(town.xp, equals(0));
      });

      test('handles overflow XP correctly across levels', () {
        final town = TownLevel(level: 1, xp: 0);
        final needed = town.xpToNext;
        // Add double the needed XP — should level up and carry over
        final leveledUp = town.addXp(needed * 2);
        expect(leveledUp, isTrue);
        expect(town.level, greaterThanOrEqualTo(2));
      });

      test('can level up multiple times with large XP', () {
        final town = TownLevel(level: 1, xp: 0);
        // Add a very large amount of XP
        town.addXp(99999);
        expect(town.level, greaterThan(1));
      });
    });

    group('toJson/fromJson', () {
      test('toJson produces correct map', () {
        final town = TownLevel(level: 3, xp: 50);
        final json = town.toJson();
        expect(json['level'], equals(3));
        expect(json['xp'], equals(50));
      });

      test('fromJson reconstructs TownLevel', () {
        final json = {'level': 7, 'xp': 300};
        final town = TownLevel.fromJson(json);
        expect(town.level, equals(7));
        expect(town.xp, equals(300));
      });

      test('fromJson handles missing fields with defaults', () {
        final town = TownLevel.fromJson({});
        expect(town.level, equals(1));
        expect(town.xp, equals(0));
      });

      test('roundtrip preserves data', () {
        final original = TownLevel(level: 4, xp: 120);
        final json = original.toJson();
        final restored = TownLevel.fromJson(json);
        expect(restored.level, equals(original.level));
        expect(restored.xp, equals(original.xp));
      });
    });
  });
}
