import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';

void main() {
  group('TownScale', () {
    group('fromLevel', () {
      test('Lv.1〜10 は荒野のキャンプ', () {
        expect(TownScale.fromLevel(1), equals(TownScale.wildernessCamp));
        expect(TownScale.fromLevel(5), equals(TownScale.wildernessCamp));
        expect(TownScale.fromLevel(10), equals(TownScale.wildernessCamp));
      });

      test('Lv.11〜25 は小さな集落', () {
        expect(TownScale.fromLevel(11), equals(TownScale.smallSettlement));
        expect(TownScale.fromLevel(18), equals(TownScale.smallSettlement));
        expect(TownScale.fromLevel(25), equals(TownScale.smallSettlement));
      });

      test('Lv.26〜50 は活気ある町', () {
        expect(TownScale.fromLevel(26), equals(TownScale.livelyTown));
        expect(TownScale.fromLevel(38), equals(TownScale.livelyTown));
        expect(TownScale.fromLevel(50), equals(TownScale.livelyTown));
      });

      test('Lv.51〜100 は王都', () {
        expect(TownScale.fromLevel(51), equals(TownScale.royalCapital));
        expect(TownScale.fromLevel(75), equals(TownScale.royalCapital));
        expect(TownScale.fromLevel(100), equals(TownScale.royalCapital));
      });

      test('Lv.101以上 は天空の都', () {
        expect(TownScale.fromLevel(101), equals(TownScale.skyCity));
        expect(TownScale.fromLevel(150), equals(TownScale.skyCity));
        expect(TownScale.fromLevel(999), equals(TownScale.skyCity));
      });

      test('Lv.0以下は荒野のキャンプ（下限防衛）', () {
        expect(TownScale.fromLevel(0), equals(TownScale.wildernessCamp));
        expect(TownScale.fromLevel(-1), equals(TownScale.wildernessCamp));
      });
    });

    group('displayName', () {
      test('各スケールの表示名が正しい', () {
        expect(TownScale.wildernessCamp.displayName, equals('荒野のキャンプ'));
        expect(TownScale.smallSettlement.displayName, equals('小さな集落'));
        expect(TownScale.livelyTown.displayName, equals('活気ある町'));
        expect(TownScale.royalCapital.displayName, equals('王都'));
        expect(TownScale.skyCity.displayName, equals('天空の都'));
      });
    });

    group('nextScale', () {
      test('荒野のキャンプの次は小さな集落', () {
        expect(TownScale.wildernessCamp.nextScale, equals(TownScale.smallSettlement));
      });

      test('小さな集落の次は活気ある町', () {
        expect(TownScale.smallSettlement.nextScale, equals(TownScale.livelyTown));
      });

      test('活気ある町の次は王都', () {
        expect(TownScale.livelyTown.nextScale, equals(TownScale.royalCapital));
      });

      test('王都の次は天空の都', () {
        expect(TownScale.royalCapital.nextScale, equals(TownScale.skyCity));
      });

      test('天空の都の次はnull（最大）', () {
        expect(TownScale.skyCity.nextScale, isNull);
      });
    });

    group('nextLevelForUpgrade', () {
      test('荒野のキャンプ→小さな集落 の必要Lvは11', () {
        expect(TownScale.wildernessCamp.nextLevelForUpgrade, equals(11));
      });

      test('小さな集落→活気ある町 の必要Lvは26', () {
        expect(TownScale.smallSettlement.nextLevelForUpgrade, equals(26));
      });

      test('活気ある町→王都 の必要Lvは51', () {
        expect(TownScale.livelyTown.nextLevelForUpgrade, equals(51));
      });

      test('王都→天空の都 の必要Lvは101', () {
        expect(TownScale.royalCapital.nextLevelForUpgrade, equals(101));
      });

      test('天空の都は次がないのでnull', () {
        expect(TownScale.skyCity.nextLevelForUpgrade, isNull);
      });
    });
  });
}
