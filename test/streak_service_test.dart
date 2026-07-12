import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/services/streak_service.dart';

void main() {
  group('StreakService', () {
    test('calcStreakReward - 2日ストリークで100', () {
      expect(StreakService.calcStreakReward(2), 100);
    });

    test('calcStreakReward - 3日ストリークで200', () {
      expect(StreakService.calcStreakReward(3), 200);
    });

    test('calcStreakReward - 5日ストリークで500', () {
      expect(StreakService.calcStreakReward(5), 500);
    });

    test('calcStreakReward - 7日ストリークで1000', () {
      expect(StreakService.calcStreakReward(7), 1000);
    });

    test('calcStreakReward - 14日ストリークで2000', () {
      expect(StreakService.calcStreakReward(14), 2000);
    });

    test('calcStreakReward - 30日ストリークで5000', () {
      expect(StreakService.calcStreakReward(30), 5000);
    });

    test('calcStreakReward - 60日ストリークで8000', () {
      expect(StreakService.calcStreakReward(60), 8000);
    });

    test('calcStreakReward - 100日ストリークで10000', () {
      expect(StreakService.calcStreakReward(100), 10000);
    });

    test('calcStreakReward - 1日以下は0', () {
      expect(StreakService.calcStreakReward(0), 0);
      expect(StreakService.calcStreakReward(1), 0);
    });

    test('calcStreakReward - 定義外の日数は0', () {
      expect(StreakService.calcStreakReward(4), 0);
      expect(StreakService.calcStreakReward(10), 0);
    });

    test('calcStreakReward - 100日超は10000', () {
      expect(StreakService.calcStreakReward(31), 5000);
      expect(StreakService.calcStreakReward(61), 8000);
      expect(StreakService.calcStreakReward(101), 10000);
    });
  });

  group('StreakService.calcExpMultiplier', () {
    test('7日ストリークで1.2x', () {
      expect(StreakService.calcExpMultiplier(7), 1.2);
    });

    test('14日ストリークで1.5x', () {
      expect(StreakService.calcExpMultiplier(14), 1.5);
    });

    test('30日ストリークで2.0x', () {
      expect(StreakService.calcExpMultiplier(30), 2.0);
    });

    test('マイルストーン超過日数はそのマイルストーンの倍率', () {
      expect(StreakService.calcExpMultiplier(8), 1.2);
      expect(StreakService.calcExpMultiplier(13), 1.2);
      expect(StreakService.calcExpMultiplier(15), 1.5);
      expect(StreakService.calcExpMultiplier(29), 1.5);
      expect(StreakService.calcExpMultiplier(31), 2.0);
      expect(StreakService.calcExpMultiplier(100), 2.0);
    });

    test('マイルストーン未満の日数は1.0x', () {
      expect(StreakService.calcExpMultiplier(0), 1.0);
      expect(StreakService.calcExpMultiplier(1), 1.0);
      expect(StreakService.calcExpMultiplier(2), 1.0);
      expect(StreakService.calcExpMultiplier(3), 1.0);
      expect(StreakService.calcExpMultiplier(5), 1.0);
      expect(StreakService.calcExpMultiplier(6), 1.0);
    });
  });
}
