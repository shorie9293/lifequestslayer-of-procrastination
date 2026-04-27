import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/services/fatigue_service.dart';
import 'package:rpg_todo/models/player.dart';

void main() {
  group('FatigueService', () {
    test('warnThreshold - デフォルトで5', () {
      final player = Player();
      expect(FatigueService.warnThreshold(player), 5);
    });

    test('warnThreshold - todayTaskLimitOffsetが反映される', () {
      final player = Player()..todayTaskLimitOffset = 3;
      expect(FatigueService.warnThreshold(player), 8);
    });

    test('severeThreshold - デフォルトで10', () {
      final player = Player();
      expect(FatigueService.severeThreshold(player), 10);
    });

    test('severeThreshold - todayTaskLimitOffsetが反映される', () {
      final player = Player()..todayTaskLimitOffset = 5;
      expect(FatigueService.severeThreshold(player), 15);
    });

    test('status - dailyTasksCompleted=0で元気', () {
      final player = Player()..dailyTasksCompleted = 0;
      expect(FatigueService.status(player), '😄 元気');
    });

    test('status - dailyTasksCompleted=5でwarn', () {
      final player = Player()..dailyTasksCompleted = 5;
      expect(FatigueService.status(player), '🍺 十分戦った');
    });

    test('status - dailyTasksCompleted=10でsevere', () {
      final player = Player()..dailyTasksCompleted = 10;
      expect(FatigueService.status(player), '🌙 今日の英雄は休め');
    });

    test('progress - dailyTasksCompleted=5で0.5', () {
      final player = Player()..dailyTasksCompleted = 5;
      expect(FatigueService.progress(player), 0.5);
    });

    test('progress - dailyTasksCompleted=0で0.0', () {
      final player = Player()..dailyTasksCompleted = 0;
      expect(FatigueService.progress(player), 0.0);
    });

    test('progress - dailyTasksCompleted=10で1.0', () {
      final player = Player()..dailyTasksCompleted = 10;
      expect(FatigueService.progress(player), 1.0);
    });

    test('fatigueMultiplier - dailyTasksCompleted=0で1.0', () {
      final player = Player()..dailyTasksCompleted = 0;
      expect(FatigueService.fatigueMultiplier(player), 1.0);
    });

    test('fatigueMultiplier - dailyTasksCompleted=5で0.5', () {
      final player = Player()..dailyTasksCompleted = 5;
      expect(FatigueService.fatigueMultiplier(player), 0.5);
    });

    test('fatigueMultiplier - dailyTasksCompleted=10で0.1', () {
      final player = Player()..dailyTasksCompleted = 10;
      expect(FatigueService.fatigueMultiplier(player), 0.1);
    });

    test('restAtInn - コインが足りない場合はエラー', () {
      final player = Player()..coins = 0;
      final result = FatigueService.restAtInn(player, 0, DateTime.now());
      expect(result, '金貨が足りないぜ');
    });

    test('restAtInn - コインが足りる場合は成功', () {
      final player = Player()..coins = 100;
      final result = FatigueService.restAtInn(player, 0, DateTime.now());
      expect(result, isNull);
      expect(player.coins, 50); // 50コイン消費
      expect(player.nextDayTaskLimitOffset, 2);
    });

    test('restAtInn - 同じ日に2回泊まるとエラー', () {
      final now = DateTime.now();
      final player = Player()..coins = 1000;
      FatigueService.restAtInn(player, 0, now);
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, '今日はもう十分休んだ。また明日来な！');
    });

    test('restAtInn - innType=1で200コイン消費・limitBonus=5', () {
      final player = Player()..coins = 500;
      FatigueService.restAtInn(player, 1, DateTime.now());
      expect(player.coins, 300);
      expect(player.nextDayTaskLimitOffset, 5);
    });

    test('restAtInn - innType=2で1000コイン消費・limitBonus=12', () {
      final player = Player()..coins = 1500;
      FatigueService.restAtInn(player, 2, DateTime.now());
      expect(player.coins, 500);
      expect(player.nextDayTaskLimitOffset, 12);
    });

    test('restAtInn - 無効なinnTypeでエラー', () {
      final player = Player()..coins = 100;
      final result = FatigueService.restAtInn(player, 99, DateTime.now());
      expect(result, 'そんなメニューはないぜ');
    });
  });
}
