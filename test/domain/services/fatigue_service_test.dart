import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/services/fatigue_service.dart';
import 'package:rpg_todo/domain/models/player.dart';

Player createPlayer({
  int todayTaskLimitOffset = 0,
  int dailyTasksCompleted = 0,
  int coins = 1000,
  DateTime? lastRestDate,
}) {
  return Player()
    ..todayTaskLimitOffset = todayTaskLimitOffset
    ..dailyTasksCompleted = dailyTasksCompleted
    ..coins = coins
    ..lastRestDate = lastRestDate;
}

void main() {
  group('warnThreshold', () {
    test('デフォルトオフセット0で5を返す', () {
      final player = createPlayer();
      expect(FatigueService.warnThreshold(player), 5);
    });

    test('オフセット5で10を返す', () {
      final player = createPlayer(todayTaskLimitOffset: 5);
      expect(FatigueService.warnThreshold(player), 10);
    });

    test('負のオフセットでも正しく計算する（-3で2）', () {
      final player = createPlayer(todayTaskLimitOffset: -3);
      expect(FatigueService.warnThreshold(player), 2);
    });
  });

  group('severeThreshold', () {
    test('デフォルトオフセット0で10を返す', () {
      final player = createPlayer();
      expect(FatigueService.severeThreshold(player), 10);
    });

    test('オフセット5で15を返す', () {
      final player = createPlayer(todayTaskLimitOffset: 5);
      expect(FatigueService.severeThreshold(player), 15);
    });

    test('負のオフセットでも正しく計算する（-2で8）', () {
      final player = createPlayer(todayTaskLimitOffset: -2);
      expect(FatigueService.severeThreshold(player), 8);
    });
  });

  group('progress', () {
    test('クエスト完了0で0.0を返す', () {
      final player = createPlayer(dailyTasksCompleted: 0);
      expect(FatigueService.progress(player), 0.0);
    });

    test('しきい値の半分で0.5を返す', () {
      final player = createPlayer(dailyTasksCompleted: 5);
      expect(FatigueService.progress(player), 0.5);
    });

    test('しきい値と同じで1.0を返す', () {
      final player = createPlayer(dailyTasksCompleted: 10);
      expect(FatigueService.progress(player), 1.0);
    });

    test('しきい値を超えても1.0にクランプされる', () {
      final player = createPlayer(dailyTasksCompleted: 20);
      expect(FatigueService.progress(player), 1.0);
    });

    test('負の値でも0.0にクランプされる', () {
      final player = createPlayer(dailyTasksCompleted: -5);
      expect(FatigueService.progress(player), 0.0);
    });

    test('オフセットがしきい値に影響する（オフセット5、完了7で0.466...）', () {
      final player = createPlayer(
        dailyTasksCompleted: 7,
        todayTaskLimitOffset: 5,
      );
      // severeThreshold = 10 + 5 = 15, progress = 7/15 ≈ 0.4667
      expect(FatigueService.progress(player), closeTo(0.4667, 0.001));
    });
  });

  group('fatigueLevel', () {
    test('progress < 0.4 でレベル0', () {
      final player = createPlayer(dailyTasksCompleted: 3);
      expect(FatigueService.fatigueLevel(player), 0);
    });

    test('0.4 <= progress < 0.7 でレベル1', () {
      final player = createPlayer(dailyTasksCompleted: 5);
      expect(FatigueService.fatigueLevel(player), 1);
    });

    test('progress == 0.5 でレベル1', () {
      final player = createPlayer(dailyTasksCompleted: 5);
      expect(FatigueService.fatigueLevel(player), 1);
    });

    test('0.7 <= progress < 1.0 でレベル2', () {
      final player = createPlayer(dailyTasksCompleted: 8);
      expect(FatigueService.fatigueLevel(player), 2);
    });

    test('progress == 0.7 でレベル2', () {
      final player = createPlayer(dailyTasksCompleted: 7);
      expect(FatigueService.fatigueLevel(player), 2);
    });

    test('progress >= 1.0 でレベル3', () {
      final player = createPlayer(dailyTasksCompleted: 10);
      expect(FatigueService.fatigueLevel(player), 3);
    });

    test('progress が1.0を超えてもレベル3', () {
      final player = createPlayer(dailyTasksCompleted: 15);
      expect(FatigueService.fatigueLevel(player), 3);
    });
  });

  group('status', () {
    test('レベル0で 😊 快調', () {
      final player = createPlayer(dailyTasksCompleted: 0);
      expect(FatigueService.status(player), '😊 快調');
    });

    test('レベル1で 😐 やや疲れ', () {
      final player = createPlayer(dailyTasksCompleted: 5);
      expect(FatigueService.status(player), '😐 やや疲れ');
    });

    test('レベル2で 😓 疲労', () {
      final player = createPlayer(dailyTasksCompleted: 8);
      expect(FatigueService.status(player), '😓 疲労');
    });

    test('レベル3で 😵 限界', () {
      final player = createPlayer(dailyTasksCompleted: 10);
      expect(FatigueService.status(player), '😵 限界');
    });

    test('境界値: progress 0.4ちょうどでレベル1', () {
      final player = createPlayer(dailyTasksCompleted: 4);
      expect(FatigueService.status(player), '😐 やや疲れ');
    });

    test('境界値: progress 0.7ちょうどでレベル2', () {
      final player = createPlayer(dailyTasksCompleted: 7);
      expect(FatigueService.status(player), '😓 疲労');
    });
  });

  group('fatigueMultiplier', () {
    test('警告しきい値未満で1.0', () {
      final player = createPlayer(dailyTasksCompleted: 4);
      expect(FatigueService.fatigueMultiplier(player), 1.0);
    });

    test('警告しきい値以上、重度しきい値未満で0.5', () {
      final player = createPlayer(dailyTasksCompleted: 5);
      expect(FatigueService.fatigueMultiplier(player), 0.5);
    });

    test('重度しきい値以上で0.1', () {
      final player = createPlayer(dailyTasksCompleted: 10);
      expect(FatigueService.fatigueMultiplier(player), 0.1);
    });

    test('重度しきい値を超えても0.1', () {
      final player = createPlayer(dailyTasksCompleted: 15);
      expect(FatigueService.fatigueMultiplier(player), 0.1);
    });

    test('完了0で1.0', () {
      final player = createPlayer(dailyTasksCompleted: 0);
      expect(FatigueService.fatigueMultiplier(player), 1.0);
    });

    test('オフセットがしきい値に影響する', () {
      // warn=5+2=7, severe=10+2=12
      final player = createPlayer(
        dailyTasksCompleted: 8,
        todayTaskLimitOffset: 2,
      );
      // 8 >= 7 (警告) かつ 8 < 12 (重度未満) → 0.5
      expect(FatigueService.fatigueMultiplier(player), 0.5);
    });
  });

  group('restAtInn', () {
    test('同日に既に休んだ場合はエラーを返す', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(
        lastRestDate: DateTime(2026, 5, 22, 8, 30),
      );
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, '今日はもう十分休んだ。また明日来な！');
    });

    test('異なる日なら再度休める', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(
        lastRestDate: DateTime(2026, 5, 21, 8, 30),
        coins: 1000,
      );
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, isNull);
    });

    test('lastRestDateがnullなら休める', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 1000);
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, isNull);
    });

    test('コインが足りない場合はエラーを返す', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 10);
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, '文が足りないぜ');
    });

    test('無効なinnTypeでエラーを返す', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 1000);
      final result = FatigueService.restAtInn(player, 99, now);
      expect(result, 'そんなメニューはないぜ');
    });

    test('innType 0: 50コイン消費、limitBonus=2', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 100);
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, isNull);
      expect(player.coins, 50);
      expect(player.nextDayTaskLimitOffset, 2);
      expect(player.lastRestDate, now);
    });

    test('innType 1: 200コイン消費、limitBonus=5', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 500);
      final result = FatigueService.restAtInn(player, 1, now);
      expect(result, isNull);
      expect(player.coins, 300);
      expect(player.nextDayTaskLimitOffset, 5);
      expect(player.lastRestDate, now);
    });

    test('innType 2: 1000コイン消費、limitBonus=12', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 1500);
      final result = FatigueService.restAtInn(player, 2, now);
      expect(result, isNull);
      expect(player.coins, 500);
      expect(player.nextDayTaskLimitOffset, 12);
      expect(player.lastRestDate, now);
    });

    test('ギリギリのコインで宿泊できる', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 50);
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, isNull);
      expect(player.coins, 0);
    });

    test('コインが1足りない場合はエラー', () {
      final now = DateTime(2026, 5, 22, 10, 0);
      final player = createPlayer(coins: 49);
      final result = FatigueService.restAtInn(player, 0, now);
      expect(result, '文が足りないぜ');
    });
  });
}
