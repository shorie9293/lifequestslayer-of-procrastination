import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/services/streak_service.dart';

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

    test('calcStreakReward - 1日以下は0', () {
      expect(StreakService.calcStreakReward(0), 0);
      expect(StreakService.calcStreakReward(1), 0);
    });

    test('calcStreakReward - 定義外の日数は0', () {
      expect(StreakService.calcStreakReward(4), 0);
      expect(StreakService.calcStreakReward(10), 0);
      expect(StreakService.calcStreakReward(100), 0);
    });
  });
}
